import 'package:http/http.dart' as http;

void main() async {
  const String url = 'https://mediumslateblue-okapi-112468.hostingersite.com/APIS_RIVALDO/api_test.php';
  print('--- Probando API de Test ---');
  print('URL: $url');
  try {
    final response = await http.get(Uri.parse(url));
    print('--- Respuesta ---');
    print('Status Code: ${response.statusCode}');
    print('Body: ${response.body}');
  } catch (e) {
    print('--- ERROR ---');
    print(e.toString());
  }
}
