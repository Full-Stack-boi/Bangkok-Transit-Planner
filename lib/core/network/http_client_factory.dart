import 'package:http/http.dart' as http;

const String kAppUserAgent = 'BkkTransitPlanner/1.0';
const Map<String, String> kDefaultHeaders = {'User-Agent': kAppUserAgent};

http.Client createHttpClient() => http.Client();
