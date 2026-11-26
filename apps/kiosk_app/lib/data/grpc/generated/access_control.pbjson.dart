// This is a generated file - do not edit.
//
// Generated from access_control.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use outboxEventProtoDescriptor instead')
const OutboxEventProto$json = {
  '1': 'OutboxEventProto',
  '2': [
    {'1': 'event_uuid', '3': 1, '4': 1, '5': 9, '10': 'eventUuid'},
    {'1': 'turnstile_id', '3': 2, '4': 1, '5': 9, '10': 'turnstileId'},
    {'1': 'campus_id', '3': 3, '4': 1, '5': 9, '10': 'campusId'},
    {'1': 'student_id', '3': 4, '4': 1, '5': 9, '10': 'studentId'},
    {'1': 'student_rut', '3': 5, '4': 1, '5': 9, '10': 'studentRut'},
    {'1': 'access_timestamp', '3': 6, '4': 1, '5': 9, '10': 'accessTimestamp'},
    {'1': 'access_result', '3': 7, '4': 1, '5': 9, '10': 'accessResult'},
    {'1': 'denial_reason', '3': 8, '4': 1, '5': 9, '10': 'denialReason'},
    {'1': 'latency_ms', '3': 9, '4': 1, '5': 5, '10': 'latencyMs'},
    {'1': 'payload_hash', '3': 10, '4': 1, '5': 9, '10': 'payloadHash'},
  ],
};

/// Descriptor for `OutboxEventProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List outboxEventProtoDescriptor = $convert.base64Decode(
    'ChBPdXRib3hFdmVudFByb3RvEh0KCmV2ZW50X3V1aWQYASABKAlSCWV2ZW50VXVpZBIhCgx0dX'
    'Juc3RpbGVfaWQYAiABKAlSC3R1cm5zdGlsZUlkEhsKCWNhbXB1c19pZBgDIAEoCVIIY2FtcHVz'
    'SWQSHQoKc3R1ZGVudF9pZBgEIAEoCVIJc3R1ZGVudElkEh8KC3N0dWRlbnRfcnV0GAUgASgJUg'
    'pzdHVkZW50UnV0EikKEGFjY2Vzc190aW1lc3RhbXAYBiABKAlSD2FjY2Vzc1RpbWVzdGFtcBIj'
    'Cg1hY2Nlc3NfcmVzdWx0GAcgASgJUgxhY2Nlc3NSZXN1bHQSIwoNZGVuaWFsX3JlYXNvbhgIIA'
    'EoCVIMZGVuaWFsUmVhc29uEh0KCmxhdGVuY3lfbXMYCSABKAVSCWxhdGVuY3lNcxIhCgxwYXls'
    'b2FkX2hhc2gYCiABKAlSC3BheWxvYWRIYXNo');

@$core.Deprecated('Use batchIngestRequestDescriptor instead')
const BatchIngestRequest$json = {
  '1': 'BatchIngestRequest',
  '2': [
    {'1': 'turnstile_id', '3': 1, '4': 1, '5': 9, '10': 'turnstileId'},
    {'1': 'campus_id', '3': 2, '4': 1, '5': 9, '10': 'campusId'},
    {
      '1': 'dispatch_timestamp',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'dispatchTimestamp'
    },
    {'1': 'events_count', '3': 4, '4': 1, '5': 5, '10': 'eventsCount'},
    {
      '1': 'events',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.access_control.OutboxEventProto',
      '10': 'events'
    },
  ],
};

/// Descriptor for `BatchIngestRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List batchIngestRequestDescriptor = $convert.base64Decode(
    'ChJCYXRjaEluZ2VzdFJlcXVlc3QSIQoMdHVybnN0aWxlX2lkGAEgASgJUgt0dXJuc3RpbGVJZB'
    'IbCgljYW1wdXNfaWQYAiABKAlSCGNhbXB1c0lkEi0KEmRpc3BhdGNoX3RpbWVzdGFtcBgDIAEo'
    'CVIRZGlzcGF0Y2hUaW1lc3RhbXASIQoMZXZlbnRzX2NvdW50GAQgASgFUgtldmVudHNDb3VudB'
    'I4CgZldmVudHMYBSADKAsyIC5hY2Nlc3NfY29udHJvbC5PdXRib3hFdmVudFByb3RvUgZldmVu'
    'dHM=');

@$core.Deprecated('Use batchIngestResponseDescriptor instead')
const BatchIngestResponse$json = {
  '1': 'BatchIngestResponse',
  '2': [
    {'1': 'status', '3': 1, '4': 1, '5': 9, '10': 'status'},
    {'1': 'processed_at', '3': 2, '4': 1, '5': 9, '10': 'processedAt'},
    {'1': 'batch_size', '3': 3, '4': 1, '5': 5, '10': 'batchSize'},
    {
      '1': 'ack_map',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.access_control.BatchIngestResponse.AckMapEntry',
      '10': 'ackMap'
    },
    {'1': 'execution_time', '3': 5, '4': 1, '5': 9, '10': 'executionTime'},
  ],
  '3': [BatchIngestResponse_AckMapEntry$json],
};

@$core.Deprecated('Use batchIngestResponseDescriptor instead')
const BatchIngestResponse_AckMapEntry$json = {
  '1': 'AckMapEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `BatchIngestResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List batchIngestResponseDescriptor = $convert.base64Decode(
    'ChNCYXRjaEluZ2VzdFJlc3BvbnNlEhYKBnN0YXR1cxgBIAEoCVIGc3RhdHVzEiEKDHByb2Nlc3'
    'NlZF9hdBgCIAEoCVILcHJvY2Vzc2VkQXQSHQoKYmF0Y2hfc2l6ZRgDIAEoBVIJYmF0Y2hTaXpl'
    'EkgKB2Fja19tYXAYBCADKAsyLy5hY2Nlc3NfY29udHJvbC5CYXRjaEluZ2VzdFJlc3BvbnNlLk'
    'Fja01hcEVudHJ5UgZhY2tNYXASJQoOZXhlY3V0aW9uX3RpbWUYBSABKAlSDWV4ZWN1dGlvblRp'
    'bWUaOQoLQWNrTWFwRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbH'
    'VlOgI4AQ==');

@$core.Deprecated('Use syncWhitelistRequestDescriptor instead')
const SyncWhitelistRequest$json = {
  '1': 'SyncWhitelistRequest',
  '2': [
    {'1': 'turnstile_id', '3': 1, '4': 1, '5': 9, '10': 'turnstileId'},
    {'1': 'campus_id', '3': 2, '4': 1, '5': 9, '10': 'campusId'},
    {
      '1': 'last_sync_timestamp',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'lastSyncTimestamp'
    },
  ],
};

/// Descriptor for `SyncWhitelistRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncWhitelistRequestDescriptor = $convert.base64Decode(
    'ChRTeW5jV2hpdGVsaXN0UmVxdWVzdBIhCgx0dXJuc3RpbGVfaWQYASABKAlSC3R1cm5zdGlsZU'
    'lkEhsKCWNhbXB1c19pZBgCIAEoCVIIY2FtcHVzSWQSLgoTbGFzdF9zeW5jX3RpbWVzdGFtcBgD'
    'IAEoCVIRbGFzdFN5bmNUaW1lc3RhbXA=');

@$core.Deprecated('Use whitelistUserProtoDescriptor instead')
const WhitelistUserProto$json = {
  '1': 'WhitelistUserProto',
  '2': [
    {'1': 'student_id', '3': 1, '4': 1, '5': 9, '10': 'studentId'},
    {'1': 'rut', '3': 2, '4': 1, '5': 9, '10': 'rut'},
    {'1': 'full_name', '3': 3, '4': 1, '5': 9, '10': 'fullName'},
    {'1': 'role', '3': 4, '4': 1, '5': 9, '10': 'role'},
    {'1': 'career', '3': 5, '4': 1, '5': 9, '10': 'career'},
    {'1': 'campus', '3': 6, '4': 1, '5': 9, '10': 'campus'},
    {
      '1': 'enrollment_status',
      '3': 7,
      '4': 1,
      '5': 9,
      '10': 'enrollmentStatus'
    },
    {'1': 'face_vector_512', '3': 8, '4': 3, '5': 2, '10': 'faceVector512'},
  ],
};

/// Descriptor for `WhitelistUserProto`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List whitelistUserProtoDescriptor = $convert.base64Decode(
    'ChJXaGl0ZWxpc3RVc2VyUHJvdG8SHQoKc3R1ZGVudF9pZBgBIAEoCVIJc3R1ZGVudElkEhAKA3'
    'J1dBgCIAEoCVIDcnV0EhsKCWZ1bGxfbmFtZRgDIAEoCVIIZnVsbE5hbWUSEgoEcm9sZRgEIAEo'
    'CVIEcm9sZRIWCgZjYXJlZXIYBSABKAlSBmNhcmVlchIWCgZjYW1wdXMYBiABKAlSBmNhbXB1cx'
    'IrChFlbnJvbGxtZW50X3N0YXR1cxgHIAEoCVIQZW5yb2xsbWVudFN0YXR1cxImCg9mYWNlX3Zl'
    'Y3Rvcl81MTIYCCADKAJSDWZhY2VWZWN0b3I1MTI=');

@$core.Deprecated('Use syncWhitelistResponseDescriptor instead')
const SyncWhitelistResponse$json = {
  '1': 'SyncWhitelistResponse',
  '2': [
    {'1': 'total_users', '3': 1, '4': 1, '5': 5, '10': 'totalUsers'},
    {
      '1': 'users',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.access_control.WhitelistUserProto',
      '10': 'users'
    },
    {'1': 'sync_timestamp', '3': 3, '4': 1, '5': 9, '10': 'syncTimestamp'},
  ],
};

/// Descriptor for `SyncWhitelistResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncWhitelistResponseDescriptor = $convert.base64Decode(
    'ChVTeW5jV2hpdGVsaXN0UmVzcG9uc2USHwoLdG90YWxfdXNlcnMYASABKAVSCnRvdGFsVXNlcn'
    'MSOAoFdXNlcnMYAiADKAsyIi5hY2Nlc3NfY29udHJvbC5XaGl0ZWxpc3RVc2VyUHJvdG9SBXVz'
    'ZXJzEiUKDnN5bmNfdGltZXN0YW1wGAMgASgJUg1zeW5jVGltZXN0YW1w');

@$core.Deprecated('Use biometricVerifyRequestDescriptor instead')
const BiometricVerifyRequest$json = {
  '1': 'BiometricVerifyRequest',
  '2': [
    {'1': 'student_id', '3': 1, '4': 1, '5': 9, '10': 'studentId'},
    {'1': 'rut', '3': 2, '4': 1, '5': 9, '10': 'rut'},
    {'1': 'live_vector_512', '3': 3, '4': 3, '5': 2, '10': 'liveVector512'},
  ],
};

/// Descriptor for `BiometricVerifyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List biometricVerifyRequestDescriptor = $convert.base64Decode(
    'ChZCaW9tZXRyaWNWZXJpZnlSZXF1ZXN0Eh0KCnN0dWRlbnRfaWQYASABKAlSCXN0dWRlbnRJZB'
    'IQCgNydXQYAiABKAlSA3J1dBImCg9saXZlX3ZlY3Rvcl81MTIYAyADKAJSDWxpdmVWZWN0b3I1'
    'MTI=');

@$core.Deprecated('Use biometricVerifyResponseDescriptor instead')
const BiometricVerifyResponse$json = {
  '1': 'BiometricVerifyResponse',
  '2': [
    {'1': 'match', '3': 1, '4': 1, '5': 8, '10': 'match'},
    {'1': 'similarity_score', '3': 2, '4': 1, '5': 2, '10': 'similarityScore'},
    {'1': 'student_name', '3': 3, '4': 1, '5': 9, '10': 'studentName'},
    {'1': 'status', '3': 4, '4': 1, '5': 9, '10': 'status'},
  ],
};

/// Descriptor for `BiometricVerifyResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List biometricVerifyResponseDescriptor = $convert.base64Decode(
    'ChdCaW9tZXRyaWNWZXJpZnlSZXNwb25zZRIUCgVtYXRjaBgBIAEoCFIFbWF0Y2gSKQoQc2ltaW'
    'xhcml0eV9zY29yZRgCIAEoAlIPc2ltaWxhcml0eVNjb3JlEiEKDHN0dWRlbnRfbmFtZRgDIAEo'
    'CVILc3R1ZGVudE5hbWUSFgoGc3RhdHVzGAQgASgJUgZzdGF0dXM=');

@$core.Deprecated('Use healthCheckRequestDescriptor instead')
const HealthCheckRequest$json = {
  '1': 'HealthCheckRequest',
  '2': [
    {'1': 'client_id', '3': 1, '4': 1, '5': 9, '10': 'clientId'},
  ],
};

/// Descriptor for `HealthCheckRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List healthCheckRequestDescriptor =
    $convert.base64Decode(
        'ChJIZWFsdGhDaGVja1JlcXVlc3QSGwoJY2xpZW50X2lkGAEgASgJUghjbGllbnRJZA==');

@$core.Deprecated('Use healthCheckResponseDescriptor instead')
const HealthCheckResponse$json = {
  '1': 'HealthCheckResponse',
  '2': [
    {'1': 'status', '3': 1, '4': 1, '5': 9, '10': 'status'},
    {'1': 'queue_depth', '3': 2, '4': 1, '5': 5, '10': 'queueDepth'},
    {'1': 'active_workers', '3': 3, '4': 1, '5': 5, '10': 'activeWorkers'},
    {'1': 'uptime', '3': 4, '4': 1, '5': 9, '10': 'uptime'},
  ],
};

/// Descriptor for `HealthCheckResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List healthCheckResponseDescriptor = $convert.base64Decode(
    'ChNIZWFsdGhDaGVja1Jlc3BvbnNlEhYKBnN0YXR1cxgBIAEoCVIGc3RhdHVzEh8KC3F1ZXVlX2'
    'RlcHRoGAIgASgFUgpxdWV1ZURlcHRoEiUKDmFjdGl2ZV93b3JrZXJzGAMgASgFUg1hY3RpdmVX'
    'b3JrZXJzEhYKBnVwdGltZRgEIAEoCVIGdXB0aW1l');
