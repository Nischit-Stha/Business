export const DOCUMENT_MAX_BYTES = 10 * 1024 * 1024;

export const DOCUMENT_TYPES = {
  'application/pdf': { extension: 'pdf', matches: (bytes: Uint8Array) => Buffer.from(bytes.subarray(0, 5)).toString() === '%PDF-' },
  'image/jpeg': { extension: 'jpg', matches: (bytes: Uint8Array) => bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff },
  'image/png': { extension: 'png', matches: (bytes: Uint8Array) => Buffer.from(bytes.subarray(0, 8)).equals(Buffer.from([137,80,78,71,13,10,26,10])) },
} as const;

export type AllowedDocumentMime = keyof typeof DOCUMENT_TYPES;

export function detectDocumentType(bytes: Uint8Array) {
  return (Object.entries(DOCUMENT_TYPES) as [AllowedDocumentMime, (typeof DOCUMENT_TYPES)[AllowedDocumentMime]][])
    .find(([, rule]) => rule.matches(bytes));
}

export function cleanDocumentFilename(value: string) {
  const cleaned = value.normalize('NFKC').replace(/[\u0000-\u001f\u007f/\\]/g, '_').replace(/\s+/g, ' ').trim();
  return cleaned.slice(0, 255) || 'document';
}

export function buildDocumentObjectPath(subjectId: string, documentType: string, objectId: string, extension: string) {
  const customer = ['DRIVER_LICENCE', 'PROOF_OF_ADDRESS'].includes(documentType);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(subjectId)
    || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(objectId)
    || !['DRIVER_LICENCE', 'PROOF_OF_ADDRESS', 'REGISTRATION', 'RWC'].includes(documentType)
    || !['pdf', 'jpg', 'png'].includes(extension)) {
    throw new Error('Invalid document object path input');
  }
  return `${customer ? 'customers' : 'vehicles'}/${subjectId}/${documentType.toLowerCase()}/${objectId}.${extension}`;
}

export function buildAgreementDocumentObjectPath(customerId:string,agreementId:string,objectId:string){const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;if(!uuid.test(customerId)||!uuid.test(agreementId)||!uuid.test(objectId))throw new Error('Invalid agreement document path input');return `customers/${customerId}/agreements/${agreementId}/${objectId}.pdf`;}
