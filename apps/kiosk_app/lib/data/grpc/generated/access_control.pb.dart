// This is a generated file - do not edit.
//
// Generated from access_control.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Evento forense individual del torniquete
class OutboxEventProto extends $pb.GeneratedMessage {
  factory OutboxEventProto({
    $core.String? eventUuid,
    $core.String? turnstileId,
    $core.String? campusId,
    $core.String? studentId,
    $core.String? studentRut,
    $core.String? accessTimestamp,
    $core.String? accessResult,
    $core.String? denialReason,
    $core.int? latencyMs,
    $core.String? payloadHash,
  }) {
    final result = OutboxEventProto._();
    if (eventUuid != null) result.eventUuid = eventUuid;
    if (turnstileId != null) result.turnstileId = turnstileId;
    if (campusId != null) result.campusId = campusId;
    if (studentId != null) result.studentId = studentId;
    if (studentRut != null) result.studentRut = studentRut;
    if (accessTimestamp != null) result.accessTimestamp = accessTimestamp;
    if (accessResult != null) result.accessResult = accessResult;
    if (denialReason != null) result.denialReason = denialReason;
    if (latencyMs != null) result.latencyMs = latencyMs;
    if (payloadHash != null) result.payloadHash = payloadHash;
    return result;
  }

  OutboxEventProto._();

  factory OutboxEventProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OutboxEventProto()..mergeFromBuffer(data, registry);
  factory OutboxEventProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OutboxEventProto()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OutboxEventProto',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'access_control'),
      createEmptyInstance: OutboxEventProto.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'eventUuid')
    ..aOS(2, _omitFieldNames ? '' : 'turnstileId')
    ..aOS(3, _omitFieldNames ? '' : 'campusId')
    ..aOS(4, _omitFieldNames ? '' : 'studentId')
    ..aOS(5, _omitFieldNames ? '' : 'studentRut')
    ..aOS(6, _omitFieldNames ? '' : 'accessTimestamp')
    ..aOS(7, _omitFieldNames ? '' : 'accessResult')
    ..aOS(8, _omitFieldNames ? '' : 'denialReason')
    ..aI(9, _omitFieldNames ? '' : 'latencyMs')
    ..aOS(10, _omitFieldNames ? '' : 'payloadHash')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OutboxEventProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OutboxEventProto copyWith(void Function(OutboxEventProto) updates) =>
      super.copyWith((message) => updates(message as OutboxEventProto))
          as OutboxEventProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use OutboxEventProto() / OutboxEventProto.new instead')
  static OutboxEventProto create() => OutboxEventProto._();
  static $pb.GeneratedMessage $_createMessage() => OutboxEventProto._();
  @$core.override
  OutboxEventProto createEmptyInstance() => OutboxEventProto._();
  @$core.pragma('dart2js:noInline')
  static OutboxEventProto getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OutboxEventProto>(
          OutboxEventProto.$_createMessage);
  static OutboxEventProto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get eventUuid => $_getSZ(0);
  @$pb.TagNumber(1)
  set eventUuid($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEventUuid() => $_has(0);
  @$pb.TagNumber(1)
  void clearEventUuid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get turnstileId => $_getSZ(1);
  @$pb.TagNumber(2)
  set turnstileId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTurnstileId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTurnstileId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get campusId => $_getSZ(2);
  @$pb.TagNumber(3)
  set campusId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCampusId() => $_has(2);
  @$pb.TagNumber(3)
  void clearCampusId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get studentId => $_getSZ(3);
  @$pb.TagNumber(4)
  set studentId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStudentId() => $_has(3);
  @$pb.TagNumber(4)
  void clearStudentId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get studentRut => $_getSZ(4);
  @$pb.TagNumber(5)
  set studentRut($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStudentRut() => $_has(4);
  @$pb.TagNumber(5)
  void clearStudentRut() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get accessTimestamp => $_getSZ(5);
  @$pb.TagNumber(6)
  set accessTimestamp($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAccessTimestamp() => $_has(5);
  @$pb.TagNumber(6)
  void clearAccessTimestamp() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get accessResult => $_getSZ(6);
  @$pb.TagNumber(7)
  set accessResult($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAccessResult() => $_has(6);
  @$pb.TagNumber(7)
  void clearAccessResult() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get denialReason => $_getSZ(7);
  @$pb.TagNumber(8)
  set denialReason($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDenialReason() => $_has(7);
  @$pb.TagNumber(8)
  void clearDenialReason() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get latencyMs => $_getIZ(8);
  @$pb.TagNumber(9)
  set latencyMs($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLatencyMs() => $_has(8);
  @$pb.TagNumber(9)
  void clearLatencyMs() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get payloadHash => $_getSZ(9);
  @$pb.TagNumber(10)
  set payloadHash($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasPayloadHash() => $_has(9);
  @$pb.TagNumber(10)
  void clearPayloadHash() => $_clearField(10);
}

class BatchIngestRequest extends $pb.GeneratedMessage {
  factory BatchIngestRequest({
    $core.String? turnstileId,
    $core.String? campusId,
    $core.String? dispatchTimestamp,
    $core.int? eventsCount,
    $core.Iterable<OutboxEventProto>? events,
  }) {
    final result = BatchIngestRequest._();
    if (turnstileId != null) result.turnstileId = turnstileId;
    if (campusId != null) result.campusId = campusId;
    if (dispatchTimestamp != null) result.dispatchTimestamp = dispatchTimestamp;
    if (eventsCount != null) result.eventsCount = eventsCount;
    if (events != null) result.events.addAll(events);
    return result;
  }

  BatchIngestRequest._();

  factory BatchIngestRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BatchIngestRequest()..mergeFromBuffer(data, registry);
  factory BatchIngestRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BatchIngestRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BatchIngestRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'access_control'),
      createEmptyInstance: BatchIngestRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'turnstileId')
    ..aOS(2, _omitFieldNames ? '' : 'campusId')
    ..aOS(3, _omitFieldNames ? '' : 'dispatchTimestamp')
    ..aI(4, _omitFieldNames ? '' : 'eventsCount')
    ..pPM<OutboxEventProto>(5, _omitFieldNames ? '' : 'events',
        subBuilder: OutboxEventProto.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchIngestRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchIngestRequest copyWith(void Function(BatchIngestRequest) updates) =>
      super.copyWith((message) => updates(message as BatchIngestRequest))
          as BatchIngestRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use BatchIngestRequest() / BatchIngestRequest.new instead')
  static BatchIngestRequest create() => BatchIngestRequest._();
  static $pb.GeneratedMessage $_createMessage() => BatchIngestRequest._();
  @$core.override
  BatchIngestRequest createEmptyInstance() => BatchIngestRequest._();
  @$core.pragma('dart2js:noInline')
  static BatchIngestRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BatchIngestRequest>(
          BatchIngestRequest.$_createMessage);
  static BatchIngestRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get turnstileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set turnstileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTurnstileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTurnstileId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get campusId => $_getSZ(1);
  @$pb.TagNumber(2)
  set campusId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCampusId() => $_has(1);
  @$pb.TagNumber(2)
  void clearCampusId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get dispatchTimestamp => $_getSZ(2);
  @$pb.TagNumber(3)
  set dispatchTimestamp($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDispatchTimestamp() => $_has(2);
  @$pb.TagNumber(3)
  void clearDispatchTimestamp() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get eventsCount => $_getIZ(3);
  @$pb.TagNumber(4)
  set eventsCount($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEventsCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearEventsCount() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<OutboxEventProto> get events => $_getList(4);
}

class BatchIngestResponse extends $pb.GeneratedMessage {
  factory BatchIngestResponse({
    $core.String? status,
    $core.String? processedAt,
    $core.int? batchSize,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? ackMap,
    $core.String? executionTime,
  }) {
    final result = BatchIngestResponse._();
    if (status != null) result.status = status;
    if (processedAt != null) result.processedAt = processedAt;
    if (batchSize != null) result.batchSize = batchSize;
    if (ackMap != null) result.ackMap.addEntries(ackMap);
    if (executionTime != null) result.executionTime = executionTime;
    return result;
  }

  BatchIngestResponse._();

  factory BatchIngestResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BatchIngestResponse()..mergeFromBuffer(data, registry);
  factory BatchIngestResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BatchIngestResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BatchIngestResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'access_control'),
      createEmptyInstance: BatchIngestResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'status')
    ..aOS(2, _omitFieldNames ? '' : 'processedAt')
    ..aI(3, _omitFieldNames ? '' : 'batchSize')
    ..m<$core.String, $core.String>(4, _omitFieldNames ? '' : 'ackMap',
        entryClassName: 'BatchIngestResponse.AckMapEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('access_control'))
    ..aOS(5, _omitFieldNames ? '' : 'executionTime')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchIngestResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchIngestResponse copyWith(void Function(BatchIngestResponse) updates) =>
      super.copyWith((message) => updates(message as BatchIngestResponse))
          as BatchIngestResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use BatchIngestResponse() / BatchIngestResponse.new instead')
  static BatchIngestResponse create() => BatchIngestResponse._();
  static $pb.GeneratedMessage $_createMessage() => BatchIngestResponse._();
  @$core.override
  BatchIngestResponse createEmptyInstance() => BatchIngestResponse._();
  @$core.pragma('dart2js:noInline')
  static BatchIngestResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BatchIngestResponse>(
          BatchIngestResponse.$_createMessage);
  static BatchIngestResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get status => $_getSZ(0);
  @$pb.TagNumber(1)
  set status($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get processedAt => $_getSZ(1);
  @$pb.TagNumber(2)
  set processedAt($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProcessedAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearProcessedAt() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get batchSize => $_getIZ(2);
  @$pb.TagNumber(3)
  set batchSize($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBatchSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearBatchSize() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, $core.String> get ackMap => $_getMap(3);

  @$pb.TagNumber(5)
  $core.String get executionTime => $_getSZ(4);
  @$pb.TagNumber(5)
  set executionTime($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasExecutionTime() => $_has(4);
  @$pb.TagNumber(5)
  void clearExecutionTime() => $_clearField(5);
}

class SyncWhitelistRequest extends $pb.GeneratedMessage {
  factory SyncWhitelistRequest({
    $core.String? turnstileId,
    $core.String? campusId,
    $core.String? lastSyncTimestamp,
  }) {
    final result = SyncWhitelistRequest._();
    if (turnstileId != null) result.turnstileId = turnstileId;
    if (campusId != null) result.campusId = campusId;
    if (lastSyncTimestamp != null) result.lastSyncTimestamp = lastSyncTimestamp;
    return result;
  }

  SyncWhitelistRequest._();

  factory SyncWhitelistRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncWhitelistRequest()..mergeFromBuffer(data, registry);
  factory SyncWhitelistRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncWhitelistRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncWhitelistRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'access_control'),
      createEmptyInstance: SyncWhitelistRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'turnstileId')
    ..aOS(2, _omitFieldNames ? '' : 'campusId')
    ..aOS(3, _omitFieldNames ? '' : 'lastSyncTimestamp')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncWhitelistRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncWhitelistRequest copyWith(void Function(SyncWhitelistRequest) updates) =>
      super.copyWith((message) => updates(message as SyncWhitelistRequest))
          as SyncWhitelistRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SyncWhitelistRequest() / SyncWhitelistRequest.new instead')
  static SyncWhitelistRequest create() => SyncWhitelistRequest._();
  static $pb.GeneratedMessage $_createMessage() => SyncWhitelistRequest._();
  @$core.override
  SyncWhitelistRequest createEmptyInstance() => SyncWhitelistRequest._();
  @$core.pragma('dart2js:noInline')
  static SyncWhitelistRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncWhitelistRequest>(
          SyncWhitelistRequest.$_createMessage);
  static SyncWhitelistRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get turnstileId => $_getSZ(0);
  @$pb.TagNumber(1)
  set turnstileId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTurnstileId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTurnstileId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get campusId => $_getSZ(1);
  @$pb.TagNumber(2)
  set campusId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCampusId() => $_has(1);
  @$pb.TagNumber(2)
  void clearCampusId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get lastSyncTimestamp => $_getSZ(2);
  @$pb.TagNumber(3)
  set lastSyncTimestamp($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastSyncTimestamp() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastSyncTimestamp() => $_clearField(3);
}

class WhitelistUserProto extends $pb.GeneratedMessage {
  factory WhitelistUserProto({
    $core.String? studentId,
    $core.String? rut,
    $core.String? fullName,
    $core.String? role,
    $core.String? career,
    $core.String? campus,
    $core.String? enrollmentStatus,
    $core.Iterable<$core.double>? faceVector512,
  }) {
    final result = WhitelistUserProto._();
    if (studentId != null) result.studentId = studentId;
    if (rut != null) result.rut = rut;
    if (fullName != null) result.fullName = fullName;
    if (role != null) result.role = role;
    if (career != null) result.career = career;
    if (campus != null) result.campus = campus;
    if (enrollmentStatus != null) result.enrollmentStatus = enrollmentStatus;
    if (faceVector512 != null) result.faceVector512.addAll(faceVector512);
    return result;
  }

  WhitelistUserProto._();

  factory WhitelistUserProto.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WhitelistUserProto()..mergeFromBuffer(data, registry);
  factory WhitelistUserProto.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WhitelistUserProto()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WhitelistUserProto',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'access_control'),
      createEmptyInstance: WhitelistUserProto.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'studentId')
    ..aOS(2, _omitFieldNames ? '' : 'rut')
    ..aOS(3, _omitFieldNames ? '' : 'fullName')
    ..aOS(4, _omitFieldNames ? '' : 'role')
    ..aOS(5, _omitFieldNames ? '' : 'career')
    ..aOS(6, _omitFieldNames ? '' : 'campus')
    ..aOS(7, _omitFieldNames ? '' : 'enrollmentStatus')
    ..p<$core.double>(
        8, _omitFieldNames ? '' : 'faceVector512', $pb.PbFieldType.KF,
        protoName: 'face_vector_512')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WhitelistUserProto clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WhitelistUserProto copyWith(void Function(WhitelistUserProto) updates) =>
      super.copyWith((message) => updates(message as WhitelistUserProto))
          as WhitelistUserProto;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WhitelistUserProto() / WhitelistUserProto.new instead')
  static WhitelistUserProto create() => WhitelistUserProto._();
  static $pb.GeneratedMessage $_createMessage() => WhitelistUserProto._();
  @$core.override
  WhitelistUserProto createEmptyInstance() => WhitelistUserProto._();
  @$core.pragma('dart2js:noInline')
  static WhitelistUserProto getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WhitelistUserProto>(
          WhitelistUserProto.$_createMessage);
  static WhitelistUserProto? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get studentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set studentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStudentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearStudentId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get rut => $_getSZ(1);
  @$pb.TagNumber(2)
  set rut($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRut() => $_has(1);
  @$pb.TagNumber(2)
  void clearRut() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get fullName => $_getSZ(2);
  @$pb.TagNumber(3)
  set fullName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFullName() => $_has(2);
  @$pb.TagNumber(3)
  void clearFullName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get role => $_getSZ(3);
  @$pb.TagNumber(4)
  set role($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRole() => $_has(3);
  @$pb.TagNumber(4)
  void clearRole() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get career => $_getSZ(4);
  @$pb.TagNumber(5)
  set career($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCareer() => $_has(4);
  @$pb.TagNumber(5)
  void clearCareer() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get campus => $_getSZ(5);
  @$pb.TagNumber(6)
  set campus($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCampus() => $_has(5);
  @$pb.TagNumber(6)
  void clearCampus() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get enrollmentStatus => $_getSZ(6);
  @$pb.TagNumber(7)
  set enrollmentStatus($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasEnrollmentStatus() => $_has(6);
  @$pb.TagNumber(7)
  void clearEnrollmentStatus() => $_clearField(7);

  @$pb.TagNumber(8)
  $pb.PbList<$core.double> get faceVector512 => $_getList(7);
}

class SyncWhitelistResponse extends $pb.GeneratedMessage {
  factory SyncWhitelistResponse({
    $core.int? totalUsers,
    $core.Iterable<WhitelistUserProto>? users,
    $core.String? syncTimestamp,
  }) {
    final result = SyncWhitelistResponse._();
    if (totalUsers != null) result.totalUsers = totalUsers;
    if (users != null) result.users.addAll(users);
    if (syncTimestamp != null) result.syncTimestamp = syncTimestamp;
    return result;
  }

  SyncWhitelistResponse._();

  factory SyncWhitelistResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncWhitelistResponse()..mergeFromBuffer(data, registry);
  factory SyncWhitelistResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SyncWhitelistResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncWhitelistResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'access_control'),
      createEmptyInstance: SyncWhitelistResponse.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'totalUsers')
    ..pPM<WhitelistUserProto>(2, _omitFieldNames ? '' : 'users',
        subBuilder: WhitelistUserProto.$_createMessage)
    ..aOS(3, _omitFieldNames ? '' : 'syncTimestamp')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncWhitelistResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncWhitelistResponse copyWith(
          void Function(SyncWhitelistResponse) updates) =>
      super.copyWith((message) => updates(message as SyncWhitelistResponse))
          as SyncWhitelistResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SyncWhitelistResponse() / SyncWhitelistResponse.new instead')
  static SyncWhitelistResponse create() => SyncWhitelistResponse._();
  static $pb.GeneratedMessage $_createMessage() => SyncWhitelistResponse._();
  @$core.override
  SyncWhitelistResponse createEmptyInstance() => SyncWhitelistResponse._();
  @$core.pragma('dart2js:noInline')
  static SyncWhitelistResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncWhitelistResponse>(
          SyncWhitelistResponse.$_createMessage);
  static SyncWhitelistResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get totalUsers => $_getIZ(0);
  @$pb.TagNumber(1)
  set totalUsers($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTotalUsers() => $_has(0);
  @$pb.TagNumber(1)
  void clearTotalUsers() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<WhitelistUserProto> get users => $_getList(1);

  @$pb.TagNumber(3)
  $core.String get syncTimestamp => $_getSZ(2);
  @$pb.TagNumber(3)
  set syncTimestamp($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSyncTimestamp() => $_has(2);
  @$pb.TagNumber(3)
  void clearSyncTimestamp() => $_clearField(3);
}

class BiometricVerifyRequest extends $pb.GeneratedMessage {
  factory BiometricVerifyRequest({
    $core.String? studentId,
    $core.String? rut,
    $core.Iterable<$core.double>? liveVector512,
  }) {
    final result = BiometricVerifyRequest._();
    if (studentId != null) result.studentId = studentId;
    if (rut != null) result.rut = rut;
    if (liveVector512 != null) result.liveVector512.addAll(liveVector512);
    return result;
  }

  BiometricVerifyRequest._();

  factory BiometricVerifyRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BiometricVerifyRequest()..mergeFromBuffer(data, registry);
  factory BiometricVerifyRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BiometricVerifyRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BiometricVerifyRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'access_control'),
      createEmptyInstance: BiometricVerifyRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'studentId')
    ..aOS(2, _omitFieldNames ? '' : 'rut')
    ..p<$core.double>(
        3, _omitFieldNames ? '' : 'liveVector512', $pb.PbFieldType.KF,
        protoName: 'live_vector_512')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BiometricVerifyRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BiometricVerifyRequest copyWith(
          void Function(BiometricVerifyRequest) updates) =>
      super.copyWith((message) => updates(message as BiometricVerifyRequest))
          as BiometricVerifyRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use BiometricVerifyRequest() / BiometricVerifyRequest.new instead')
  static BiometricVerifyRequest create() => BiometricVerifyRequest._();
  static $pb.GeneratedMessage $_createMessage() => BiometricVerifyRequest._();
  @$core.override
  BiometricVerifyRequest createEmptyInstance() => BiometricVerifyRequest._();
  @$core.pragma('dart2js:noInline')
  static BiometricVerifyRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BiometricVerifyRequest>(
          BiometricVerifyRequest.$_createMessage);
  static BiometricVerifyRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get studentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set studentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStudentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearStudentId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get rut => $_getSZ(1);
  @$pb.TagNumber(2)
  set rut($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRut() => $_has(1);
  @$pb.TagNumber(2)
  void clearRut() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.double> get liveVector512 => $_getList(2);
}

class BiometricVerifyResponse extends $pb.GeneratedMessage {
  factory BiometricVerifyResponse({
    $core.bool? match,
    $core.double? similarityScore,
    $core.String? studentName,
    $core.String? status,
  }) {
    final result = BiometricVerifyResponse._();
    if (match != null) result.match = match;
    if (similarityScore != null) result.similarityScore = similarityScore;
    if (studentName != null) result.studentName = studentName;
    if (status != null) result.status = status;
    return result;
  }

  BiometricVerifyResponse._();

  factory BiometricVerifyResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BiometricVerifyResponse()..mergeFromBuffer(data, registry);
  factory BiometricVerifyResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BiometricVerifyResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BiometricVerifyResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'access_control'),
      createEmptyInstance: BiometricVerifyResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'match')
    ..aD(2, _omitFieldNames ? '' : 'similarityScore',
        fieldType: $pb.PbFieldType.OF)
    ..aOS(3, _omitFieldNames ? '' : 'studentName')
    ..aOS(4, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BiometricVerifyResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BiometricVerifyResponse copyWith(
          void Function(BiometricVerifyResponse) updates) =>
      super.copyWith((message) => updates(message as BiometricVerifyResponse))
          as BiometricVerifyResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use BiometricVerifyResponse() / BiometricVerifyResponse.new instead')
  static BiometricVerifyResponse create() => BiometricVerifyResponse._();
  static $pb.GeneratedMessage $_createMessage() => BiometricVerifyResponse._();
  @$core.override
  BiometricVerifyResponse createEmptyInstance() => BiometricVerifyResponse._();
  @$core.pragma('dart2js:noInline')
  static BiometricVerifyResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BiometricVerifyResponse>(
          BiometricVerifyResponse.$_createMessage);
  static BiometricVerifyResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get match => $_getBF(0);
  @$pb.TagNumber(1)
  set match($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMatch() => $_has(0);
  @$pb.TagNumber(1)
  void clearMatch() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get similarityScore => $_getN(1);
  @$pb.TagNumber(2)
  set similarityScore($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSimilarityScore() => $_has(1);
  @$pb.TagNumber(2)
  void clearSimilarityScore() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get studentName => $_getSZ(2);
  @$pb.TagNumber(3)
  set studentName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStudentName() => $_has(2);
  @$pb.TagNumber(3)
  void clearStudentName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get status => $_getSZ(3);
  @$pb.TagNumber(4)
  set status($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatus() => $_clearField(4);
}

class HealthCheckRequest extends $pb.GeneratedMessage {
  factory HealthCheckRequest({
    $core.String? clientId,
  }) {
    final result = HealthCheckRequest._();
    if (clientId != null) result.clientId = clientId;
    return result;
  }

  HealthCheckRequest._();

  factory HealthCheckRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HealthCheckRequest()..mergeFromBuffer(data, registry);
  factory HealthCheckRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HealthCheckRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HealthCheckRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'access_control'),
      createEmptyInstance: HealthCheckRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'clientId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HealthCheckRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HealthCheckRequest copyWith(void Function(HealthCheckRequest) updates) =>
      super.copyWith((message) => updates(message as HealthCheckRequest))
          as HealthCheckRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use HealthCheckRequest() / HealthCheckRequest.new instead')
  static HealthCheckRequest create() => HealthCheckRequest._();
  static $pb.GeneratedMessage $_createMessage() => HealthCheckRequest._();
  @$core.override
  HealthCheckRequest createEmptyInstance() => HealthCheckRequest._();
  @$core.pragma('dart2js:noInline')
  static HealthCheckRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HealthCheckRequest>(
          HealthCheckRequest.$_createMessage);
  static HealthCheckRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get clientId => $_getSZ(0);
  @$pb.TagNumber(1)
  set clientId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasClientId() => $_has(0);
  @$pb.TagNumber(1)
  void clearClientId() => $_clearField(1);
}

class HealthCheckResponse extends $pb.GeneratedMessage {
  factory HealthCheckResponse({
    $core.String? status,
    $core.int? queueDepth,
    $core.int? activeWorkers,
    $core.String? uptime,
  }) {
    final result = HealthCheckResponse._();
    if (status != null) result.status = status;
    if (queueDepth != null) result.queueDepth = queueDepth;
    if (activeWorkers != null) result.activeWorkers = activeWorkers;
    if (uptime != null) result.uptime = uptime;
    return result;
  }

  HealthCheckResponse._();

  factory HealthCheckResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HealthCheckResponse()..mergeFromBuffer(data, registry);
  factory HealthCheckResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      HealthCheckResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HealthCheckResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'access_control'),
      createEmptyInstance: HealthCheckResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'status')
    ..aI(2, _omitFieldNames ? '' : 'queueDepth')
    ..aI(3, _omitFieldNames ? '' : 'activeWorkers')
    ..aOS(4, _omitFieldNames ? '' : 'uptime')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HealthCheckResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HealthCheckResponse copyWith(void Function(HealthCheckResponse) updates) =>
      super.copyWith((message) => updates(message as HealthCheckResponse))
          as HealthCheckResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use HealthCheckResponse() / HealthCheckResponse.new instead')
  static HealthCheckResponse create() => HealthCheckResponse._();
  static $pb.GeneratedMessage $_createMessage() => HealthCheckResponse._();
  @$core.override
  HealthCheckResponse createEmptyInstance() => HealthCheckResponse._();
  @$core.pragma('dart2js:noInline')
  static HealthCheckResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HealthCheckResponse>(
          HealthCheckResponse.$_createMessage);
  static HealthCheckResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get status => $_getSZ(0);
  @$pb.TagNumber(1)
  set status($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get queueDepth => $_getIZ(1);
  @$pb.TagNumber(2)
  set queueDepth($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQueueDepth() => $_has(1);
  @$pb.TagNumber(2)
  void clearQueueDepth() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get activeWorkers => $_getIZ(2);
  @$pb.TagNumber(3)
  set activeWorkers($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasActiveWorkers() => $_has(2);
  @$pb.TagNumber(3)
  void clearActiveWorkers() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get uptime => $_getSZ(3);
  @$pb.TagNumber(4)
  set uptime($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUptime() => $_has(3);
  @$pb.TagNumber(4)
  void clearUptime() => $_clearField(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
