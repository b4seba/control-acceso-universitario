import json

# NFC Payload
nfc_payload = {
    'protocol': 'NFC_HCE_ISO_14443_4',
    'frequency': '13.56MHz',
    'student_id': 'ua-stu-2026-001',
    'rut': '21.460.709-3',
    'role': 'ESTUDIANTE',
    'full_name': 'Sebastián Freire',
    'timestamp': '2026-10-25T03:30:00Z',
    'nonce': 'abc123xyz',
    'signature': 'sig123',
}
nfc_json_str = json.dumps(nfc_payload)
print("NFC JSON String:")
print(nfc_json_str)

# QR Payload
qr_payload = {
    'type': 'UA_DYNAMIC_QR_FALLBACK',
    'student_id': 'ua-stu-2026-001',
    'rut': '21.460.709-3',
    'role': 'ESTUDIANTE',
    'totp': '654321',
    'time_step': 123456,
    'sig': 'sig456',
}
qr_json_str = json.dumps(qr_payload)
print("\nQR JSON String:")
print(qr_json_str)

# Test parsing logic from KioskViewModel:
for raw in [nfc_json_str, qr_json_str, "21.460.709-3", "ua-stu-2026-001"]:
    query = raw.strip()
    try:
        decoded = json.loads(query)
        if isinstance(decoded, dict):
            query = decoded.get('rut') or decoded.get('student_id') or query
    except Exception:
        pass
    print(f"\nRaw: {raw[:30]}... => Parsed Query: {query}")
