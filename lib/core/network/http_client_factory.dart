import 'package:http/http.dart' as http;

/// Centralized User-Agent string used by all HTTP services.
const String kAppUserAgent = 'BkkTransitPlanner/1.0';

/// Default headers applied to every outgoing HTTP request.
const Map<String, String> kDefaultHeaders = {'User-Agent': kAppUserAgent};

/// Creates a shared [http.Client] instance.
///
/// All services should receive an [http.Client] via constructor injection
/// instead of calling top-level [http.get] / [http.post] directly.
/// This enables TCP connection reuse and makes services testable.
http.Client createHttpClient() => http.Client();
