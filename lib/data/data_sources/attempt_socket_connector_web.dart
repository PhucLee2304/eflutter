import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectAttemptSocket(Uri uri, String token) {
  final authenticatedUri = uri.replace(
    queryParameters: {...uri.queryParameters, 'access_token': token},
  );
  return HtmlWebSocketChannel.connect(authenticatedUri);
}
