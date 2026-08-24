-- Veera V2 bootstrap only. Business tables will be introduced in later migrations.
create schema if not exists app_private;

comment on schema app_private is
  'Server-only Veera V2 objects that must never be exposed through the Data API.';

revoke all on schema app_private from public;
revoke all on schema app_private from anon;
revoke all on schema app_private from authenticated;

