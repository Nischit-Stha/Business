import { describe, expect, it } from 'vitest';
import { buildDocumentObjectPath, cleanDocumentFilename, detectDocumentType, DOCUMENT_MAX_BYTES } from './document-validation';

const subjectId = '47000000-0000-4000-8000-000000000001';
const objectId = '10000000-0000-4000-8000-000000000001';

describe('private document validation', () => {
  it('detects supported content from bytes rather than a client MIME claim', () => {
    expect(detectDocumentType(new TextEncoder().encode('%PDF-synthetic'))?.[0]).toBe('application/pdf');
    expect(detectDocumentType(Uint8Array.from([0xff, 0xd8, 0xff, 0x00]))?.[0]).toBe('image/jpeg');
    expect(detectDocumentType(Uint8Array.from([137, 80, 78, 71, 13, 10, 26, 10]))?.[0]).toBe('image/png');
  });

  it('rejects unsupported executable content', () => {
    expect(detectDocumentType(Uint8Array.from([0x4d, 0x5a, 0x90, 0x00]))).toBeUndefined();
  });

  it('uses the documented ten MiB limit', () => {
    expect(DOCUMENT_MAX_BYTES).toBe(10_485_760);
  });

  it('generates a subject-scoped path without using the original filename', () => {
    expect(buildDocumentObjectPath(subjectId, 'DRIVER_LICENCE', objectId, 'pdf'))
      .toBe(`customers/${subjectId}/driver_licence/${objectId}.pdf`);
    expect(() => buildDocumentObjectPath('../escape', 'RWC', objectId, 'pdf')).toThrow(/invalid/i);
  });

  it('removes traversal and control characters from display filenames', () => {
    expect(cleanDocumentFilename('../licence\u0000.pdf')).toBe('.._licence_.pdf');
  });
});
