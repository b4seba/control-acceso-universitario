import 'package:grpc/grpc.dart';
import '../config/backend_config.dart';
import 'generated/access_control.pbgrpc.dart';

/// Cliente gRPC compartido para comunicación Edge-to-Cloud (:50051) con JWT RFC 7519.
class KioskGrpcClient {
  static CallOptions authOptions({
    Duration timeout = const Duration(seconds: 3),
  }) {
    return CallOptions(
      metadata: {'authorization': 'Bearer UA_EDGE_TOKEN_2026_JWT'},
      timeout: timeout,
    );
  }

  static Future<T> withClient<T>(
    Future<T> Function(TurnstileIngestServiceClient client) action, {
    String? hostOverride,
  }) async {
    final host = hostOverride ?? BackendConfig.grpcHost;
    final channel = ClientChannel(
      host,
      port: BackendConfig.grpcPort,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );

    try {
      final client = TurnstileIngestServiceClient(channel);
      return await action(client);
    } finally {
      await channel.shutdown();
    }
  }
}
