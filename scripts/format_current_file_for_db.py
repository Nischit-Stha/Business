from __future__ import annotations

import math
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
INPUT_XLSX = ROOT / "Current file.xlsx"
OUT_DIR = ROOT / "imports"
OUT_CSV = OUT_DIR / "current_file_cleaned.csv"
OUT_SQL = OUT_DIR / "current_file_to_supabase.sql"
OUT_REPORT = OUT_DIR / "current_file_profile.txt"

EXPECTED_COLUMNS = {
    "Plate number of Active": "plate",
    "Make": "make",
    "Model": "model",
    "Colour": "color",
    "Name": "customer_name",
    "Per week Expected credits": "expected_weekly_credits",
    "Pending": "pending_raw",
    "Received": "received_raw",
    "Days": "due_day",
}


def sql_quote(value: object) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, float) and math.isnan(value):
        return "NULL"
    text = str(value)
    return "'" + text.replace("'", "''") + "'"


def to_amount(value: object) -> float:
    if value is None:
        return 0.0
    if isinstance(value, float) and math.isnan(value):
        return 0.0

    text = str(value).strip()
    if not text:
        return 0.0
    lowered = text.lower()
    if lowered in {"clear", "nil", "na", "n/a", "none", "-"}:
        return 0.0

    text = text.replace(",", "")
    try:
        return float(text)
    except ValueError:
        return 0.0


def normalize_plate(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, float) and math.isnan(value):
        return ""
    return str(value).strip().upper().replace(" ", "")


def normalize_text(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, float) and math.isnan(value):
        return ""
    return " ".join(str(value).strip().split())


def normalize_name(value: object) -> str:
    name = normalize_text(value)
    if not name:
        return ""
    return " ".join(part.capitalize() for part in name.split(" "))


def normalize_day(value: object) -> str:
    day = normalize_text(value)
    if not day:
        return "NIL"
    lowered = day.lower()
    if lowered in {"nil", "na", "n/a", "none", "-"}:
        return "NIL"
    weekdays = {"monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"}
    if lowered in weekdays:
        return lowered.capitalize()
    return "NIL"


def normalize_color(value: object) -> str:
    color = normalize_text(value)
    return color.upper() if color else ""


def looks_like_plate(value: str) -> bool:
    text = normalize_plate(value)
    if not text:
        return False
    if len(text) < 5:
        return False
    has_letter = any(ch.isalpha() for ch in text)
    has_digit = any(ch.isdigit() for ch in text)
    return has_letter and has_digit


def build_import_sql(clean_df: pd.DataFrame) -> str:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    lines: list[str] = []

    lines.extend(
        [
            "-- Auto-generated from Current file.xlsx",
            f"-- Generated at: {now}",
            "-- This script imports weekly collection data and syncs vehicles/customers.",
            "",
            "BEGIN;",
            "",
            "CREATE TABLE IF NOT EXISTS public.weekly_collection_ledger (",
            "  id BIGSERIAL PRIMARY KEY,",
            "  plate TEXT NOT NULL,",
            "  make TEXT,",
            "  model TEXT,",
            "  color TEXT,",
            "  customer_name TEXT NOT NULL,",
            "  expected_weekly_credits NUMERIC NOT NULL DEFAULT 0,",
            "  pending_amount NUMERIC NOT NULL DEFAULT 0,",
            "  received_amount NUMERIC NOT NULL DEFAULT 0,",
            "  due_day TEXT,",
            "  source_file TEXT NOT NULL DEFAULT 'Current file.xlsx',",
            "  imported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),",
            "  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()",
            ");",
            "",
            "CREATE INDEX IF NOT EXISTS weekly_collection_ledger_plate_idx ON public.weekly_collection_ledger (plate);",
            "CREATE INDEX IF NOT EXISTS weekly_collection_ledger_customer_idx ON public.weekly_collection_ledger (customer_name);",
            "CREATE INDEX IF NOT EXISTS weekly_collection_ledger_imported_at_idx ON public.weekly_collection_ledger (imported_at DESC);",
            "",
            "ALTER TABLE public.weekly_collection_ledger ENABLE ROW LEVEL SECURITY;",
            "",
            "DROP POLICY IF EXISTS weekly_collection_ledger_admin_only ON public.weekly_collection_ledger;",
            "CREATE POLICY weekly_collection_ledger_admin_only",
            "ON public.weekly_collection_ledger",
            "FOR ALL",
            "TO authenticated",
            "USING (public.is_admin())",
            "WITH CHECK (public.is_admin());",
            "",
            "CREATE TEMP TABLE tmp_weekly_import (",
            "  plate TEXT,",
            "  make TEXT,",
            "  model TEXT,",
            "  color TEXT,",
            "  customer_name TEXT,",
            "  expected_weekly_credits NUMERIC,",
            "  pending_amount NUMERIC,",
            "  received_amount NUMERIC,",
            "  due_day TEXT",
            ");",
            "",
            "INSERT INTO tmp_weekly_import (plate, make, model, color, customer_name, expected_weekly_credits, pending_amount, received_amount, due_day)",
            "VALUES",
        ]
    )

    value_lines = []
    for _, row in clean_df.iterrows():
        value_lines.append(
            "  ("
            + ", ".join(
                [
                    sql_quote(row["plate"]),
                    sql_quote(row["make"]),
                    sql_quote(row["model"]),
                    sql_quote(row["color"]),
                    sql_quote(row["customer_name"]),
                    str(float(row["expected_weekly_credits"])),
                    str(float(row["pending_amount"])),
                    str(float(row["received_amount"])),
                    sql_quote(row["due_day"]),
                ]
            )
            + ")"
        )
    lines.append(",\n".join(value_lines) + ";")

    lines.extend(
        [
            "",
            "INSERT INTO public.weekly_collection_ledger (",
            "  plate, make, model, color, customer_name, expected_weekly_credits, pending_amount, received_amount, due_day",
            ")",
            "SELECT",
            "  plate, make, model, color, customer_name, expected_weekly_credits, pending_amount, received_amount, due_day",
            "FROM tmp_weekly_import",
            "ORDER BY plate, customer_name;",
            "",
            "-- Sync vehicles table from latest import",
            "UPDATE public.vehicles v",
            "SET",
            "  make = COALESCE(NULLIF(t.make, ''), v.make),",
            "  model = COALESCE(NULLIF(t.model, ''), v.model),",
            "  color = COALESCE(NULLIF(t.color, ''), v.color),",
            "  name = COALESCE(NULLIF(v.name, ''), CONCAT_WS(' ', NULLIF(t.make, ''), NULLIF(t.model, ''))),",
            "  updated_at = NOW()",
            "FROM tmp_weekly_import t",
            "WHERE UPPER(COALESCE(v.plate, '')) = UPPER(COALESCE(t.plate, ''));",
            "",
            "INSERT INTO public.vehicles (name, make, model, plate, color, status, created_at, updated_at)",
            "SELECT",
            "  CONCAT_WS(' ', NULLIF(t.make, ''), NULLIF(t.model, '')) AS name,",
            "  NULLIF(t.make, ''),",
            "  NULLIF(t.model, ''),",
            "  NULLIF(t.plate, ''),",
            "  NULLIF(t.color, ''),",
            "  'rented',",
            "  NOW(),",
            "  NOW()",
            "FROM tmp_weekly_import t",
            "WHERE NULLIF(t.plate, '') IS NOT NULL",
            "  AND NOT EXISTS (",
            "    SELECT 1 FROM public.vehicles v",
            "    WHERE UPPER(COALESCE(v.plate, '')) = UPPER(COALESCE(t.plate, ''))",
            "  );",
            "",
            "-- Sync customers table (best effort without phone/email)",
            "UPDATE public.customers c",
            "SET",
            "  current_vehicle = COALESCE(NULLIF(t.plate, ''), c.current_vehicle),",
            "  notes = CONCAT_WS(' | ', NULLIF(c.notes, ''), CONCAT('Weekly due: ', COALESCE(NULLIF(t.due_day, ''), 'NIL'))),",
            "  last_booking_at = COALESCE(c.last_booking_at, NOW()),",
            "  updated_at = NOW()",
            "FROM tmp_weekly_import t",
            "WHERE LOWER(COALESCE(c.full_name, '')) = LOWER(COALESCE(t.customer_name, ''))",
            "  AND c.full_name IS NOT NULL;",
            "",
            "INSERT INTO public.customers (full_name, current_vehicle, notes, last_booking_at, created_at, updated_at)",
            "SELECT",
            "  t.customer_name,",
            "  NULLIF(t.plate, ''),",
            "  CONCAT('Weekly due: ', COALESCE(NULLIF(t.due_day, ''), 'NIL')),",
            "  NOW(),",
            "  NOW(),",
            "  NOW()",
            "FROM tmp_weekly_import t",
            "WHERE NULLIF(t.customer_name, '') IS NOT NULL",
            "  AND NOT EXISTS (",
            "    SELECT 1 FROM public.customers c",
            "    WHERE LOWER(COALESCE(c.full_name, '')) = LOWER(COALESCE(t.customer_name, ''))",
            "  );",
            "",
            "DROP TABLE IF EXISTS tmp_weekly_import;",
            "",
            "COMMIT;",
            "",
            "-- Verification",
            "-- SELECT COUNT(*) AS imported_rows FROM public.weekly_collection_ledger WHERE source_file = 'Current file.xlsx';",
            "-- SELECT plate, customer_name, expected_weekly_credits, pending_amount, received_amount, due_day FROM public.weekly_collection_ledger ORDER BY plate, customer_name LIMIT 50;",
        ]
    )

    return "\n".join(lines)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    df = pd.read_excel(INPUT_XLSX, sheet_name="Current file")
    missing = [c for c in EXPECTED_COLUMNS if c not in df.columns]
    if missing:
        raise ValueError(f"Missing expected columns in XLSX: {missing}")

    df = df.rename(columns=EXPECTED_COLUMNS)
    clean = pd.DataFrame()
    clean["plate"] = df["plate"].map(normalize_plate)
    clean["make"] = df["make"].map(normalize_text).str.upper()
    clean["model"] = df["model"].map(normalize_text).str.upper()
    clean["color"] = df["color"].map(normalize_color)
    clean["customer_name"] = df["customer_name"].map(normalize_name)
    clean["expected_weekly_credits"] = df["expected_weekly_credits"].map(to_amount)
    clean["pending_amount"] = df["pending_raw"].map(to_amount)
    clean["received_amount"] = df["received_raw"].map(to_amount)
    clean["due_day"] = df["due_day"].map(normalize_day)

    clean = clean[clean["plate"].map(looks_like_plate)]
    clean = clean[~clean["customer_name"].str.lower().isin({"total", "car is with"})]
    clean = clean.sort_values(["plate", "customer_name"], kind="stable").reset_index(drop=True)

    clean.to_csv(OUT_CSV, index=False)
    OUT_SQL.write_text(build_import_sql(clean), encoding="utf-8")

    report_lines = [
        "Workbook profile",
        "================",
        f"input_file: {INPUT_XLSX}",
        f"output_csv: {OUT_CSV}",
        f"output_sql: {OUT_SQL}",
        f"rows_after_cleaning: {len(clean)}",
        f"unique_plates: {clean['plate'].nunique()}",
        f"unique_customers: {clean['customer_name'].nunique()}",
        f"sum_expected_weekly_credits: {clean['expected_weekly_credits'].sum():.2f}",
        f"sum_pending_amount: {clean['pending_amount'].sum():.2f}",
        f"sum_received_amount: {clean['received_amount'].sum():.2f}",
        "",
        "Top 10 due_day values:",
        clean["due_day"].value_counts(dropna=False).head(10).to_string(),
    ]
    OUT_REPORT.write_text("\n".join(report_lines), encoding="utf-8")

    print(f"Created: {OUT_CSV}")
    print(f"Created: {OUT_SQL}")
    print(f"Created: {OUT_REPORT}")
    print(f"Rows cleaned: {len(clean)}")


if __name__ == "__main__":
    main()
