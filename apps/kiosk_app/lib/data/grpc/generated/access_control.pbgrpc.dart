// This is a generated file - do not edit.
//
// Generated from access_control.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'access_control.pb.dart' as $0;

export 'access_control.pb.dart';

/// Servicio gRPC de Control de Acceso Perimetral e Ingesta de Torniquetes
@$pb.GrpcServiceName('access_control.TurnstileIngestService')
class TurnstileIngestServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  TurnstileIngestServiceClient(super.channel,
      {super.options, super.interceptors});

  /// Ingesta masiva de eventos transaccionales desde el Outbox de los torniquetes
  $grpc.ResponseFuture<$0.BatchIngestResponse> ingestBatch(
    $0.BatchIngestRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$ingestBatch, request, options: options);
  }

  /// Sincronización de lista blanca y vectores 512D para operación en Modo Isla
  $grpc.ResponseFuture<$0.SyncWhitelistResponse> syncWhitelist(
    $0.SyncWhitelistRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$syncWhitelist, request, options: options);
  }

  /// Verificación biométrica 1:1 directa en backend
  $grpc.ResponseFuture<$0.BiometricVerifyResponse> verifyBiometric(
    $0.BiometricVerifyRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$verifyBiometric, request, options: options);
  }

  /// Healthcheck de alta frecuencia del nodo central
  $grpc.ResponseFuture<$0.HealthCheckResponse> healthCheck(
    $0.HealthCheckRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$healthCheck, request, options: options);
  }

  // method descriptors

  static final _$ingestBatch =
      $grpc.ClientMethod<$0.BatchIngestRequest, $0.BatchIngestResponse>(
          '/access_control.TurnstileIngestService/IngestBatch',
          ($0.BatchIngestRequest value) => value.writeToBuffer(),
          $0.BatchIngestResponse.fromBuffer);
  static final _$syncWhitelist =
      $grpc.ClientMethod<$0.SyncWhitelistRequest, $0.SyncWhitelistResponse>(
          '/access_control.TurnstileIngestService/SyncWhitelist',
          ($0.SyncWhitelistRequest value) => value.writeToBuffer(),
          $0.SyncWhitelistResponse.fromBuffer);
  static final _$verifyBiometric =
      $grpc.ClientMethod<$0.BiometricVerifyRequest, $0.BiometricVerifyResponse>(
          '/access_control.TurnstileIngestService/VerifyBiometric',
          ($0.BiometricVerifyRequest value) => value.writeToBuffer(),
          $0.BiometricVerifyResponse.fromBuffer);
  static final _$healthCheck =
      $grpc.ClientMethod<$0.HealthCheckRequest, $0.HealthCheckResponse>(
          '/access_control.TurnstileIngestService/HealthCheck',
          ($0.HealthCheckRequest value) => value.writeToBuffer(),
          $0.HealthCheckResponse.fromBuffer);
}

@$pb.GrpcServiceName('access_control.TurnstileIngestService')
abstract class TurnstileIngestServiceBase extends $grpc.Service {
  $core.String get $name => 'access_control.TurnstileIngestService';

  TurnstileIngestServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.BatchIngestRequest, $0.BatchIngestResponse>(
            'IngestBatch',
            ingestBatch_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.BatchIngestRequest.fromBuffer(value),
            ($0.BatchIngestResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SyncWhitelistRequest, $0.SyncWhitelistResponse>(
            'SyncWhitelist',
            syncWhitelist_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SyncWhitelistRequest.fromBuffer(value),
            ($0.SyncWhitelistResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.BiometricVerifyRequest,
            $0.BiometricVerifyResponse>(
        'VerifyBiometric',
        verifyBiometric_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.BiometricVerifyRequest.fromBuffer(value),
        ($0.BiometricVerifyResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.HealthCheckRequest, $0.HealthCheckResponse>(
            'HealthCheck',
            healthCheck_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.HealthCheckRequest.fromBuffer(value),
            ($0.HealthCheckResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.BatchIngestResponse> ingestBatch_Pre($grpc.ServiceCall $call,
      $async.Future<$0.BatchIngestRequest> $request) async {
    return ingestBatch($call, await $request);
  }

  $async.Future<$0.BatchIngestResponse> ingestBatch(
      $grpc.ServiceCall call, $0.BatchIngestRequest request);

  $async.Future<$0.SyncWhitelistResponse> syncWhitelist_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SyncWhitelistRequest> $request) async {
    return syncWhitelist($call, await $request);
  }

  $async.Future<$0.SyncWhitelistResponse> syncWhitelist(
      $grpc.ServiceCall call, $0.SyncWhitelistRequest request);

  $async.Future<$0.BiometricVerifyResponse> verifyBiometric_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.BiometricVerifyRequest> $request) async {
    return verifyBiometric($call, await $request);
  }

  $async.Future<$0.BiometricVerifyResponse> verifyBiometric(
      $grpc.ServiceCall call, $0.BiometricVerifyRequest request);

  $async.Future<$0.HealthCheckResponse> healthCheck_Pre($grpc.ServiceCall $call,
      $async.Future<$0.HealthCheckRequest> $request) async {
    return healthCheck($call, await $request);
  }

  $async.Future<$0.HealthCheckResponse> healthCheck(
      $grpc.ServiceCall call, $0.HealthCheckRequest request);
}
