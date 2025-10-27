package th.mi.navy.navy_encrypt;

import android.content.Intent;
import android.os.Bundle;

import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    private static final String TAG = MainActivity.class.getSimpleName();
    private static final String CHANNEL = "app.channel.shared.data";

    private String uriPath;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        Intent intent = getIntent();
        String action = intent.getAction();
        String type = intent.getType();

        if (Intent.ACTION_VIEW.equals(action) && type != null) {
            if ("application/octet-stream".equals(type)) {
                uriPath = intent.getDataString();
            }
        }

        super.onCreate(savedInstanceState);
    }

  /*@Override
  public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
    GeneratedPluginRegistrant.registerWith(flutterEngine);

    new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
        .setMethodCallHandler(
            (call, result) -> {
              if (call.method.contentEquals("getUriPath")) {
                result.success(uriPath);
                uriPath = null;
              }
            }
        );
  }*/
}
