package com.uniucy.music;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.media.MediaMetadata;
import android.media.session.MediaSession;
import android.media.session.PlaybackState;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.util.Log;

import org.json.JSONObject;

import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * 前台播放服务 + 媒体通知。播放本体仍在 ArkTS 的 AVPlayer 中，
 * 这里负责保活、锁屏/耳机按键与通知展示，动作通过 bridge 回传。
 */
public class MediaService extends Service {
    private static final String TAG = "JianYinMedia";
    private static final String CHANNEL_ID = "playback";
    private static final int NOTIFICATION_ID = 1001;
    private static final String PREFIX = "com.uniucy.music.media.";
    public static final String ACTION_START = PREFIX + "START";
    public static final String ACTION_STOP = PREFIX + "STOP";
    public static final String ACTION_UPDATE = PREFIX + "UPDATE";
    public static final String ACTION_PLAY = PREFIX + "PLAY";
    public static final String ACTION_PAUSE = PREFIX + "PAUSE";
    public static final String ACTION_NEXT = PREFIX + "NEXT";
    public static final String ACTION_PREV = PREFIX + "PREV";
    private static final String EXTRA_JSON = "json";

    private final ExecutorService io = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());

    private MediaSession session;
    private AudioManager audioManager;
    private AudioFocusRequest focusRequest;
    private boolean hasFocus;
    private boolean foreground;

    private String title = "";
    private String artist = "";
    private String album = "";
    private String artUrl = "";
    private long duration;
    private long position;
    private boolean playing;
    private float speed = 1f;
    private Bitmap artwork;

    public static void start(Context context) {
        Intent intent = new Intent(context, MediaService.class).setAction(ACTION_START);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent);
        } else {
            context.startService(intent);
        }
    }

    public static void update(Context context, String json) {
        Intent intent = new Intent(context, MediaService.class).setAction(ACTION_UPDATE).putExtra(EXTRA_JSON, json);
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent);
            } else {
                context.startService(intent);
            }
        } catch (Throwable t) {
            Log.w(TAG, "update failed", t);
        }
    }

    public static void stop(Context context) {
        context.stopService(new Intent(context, MediaService.class));
    }

    @Override
    public void onCreate() {
        super.onCreate();
        audioManager = (AudioManager) getSystemService(AUDIO_SERVICE);
        createChannel();
        session = new MediaSession(this, "JianYin");
        session.setCallback(new MediaSession.Callback() {
            @Override
            public void onPlay() {
                AppBridgePlugin.dispatch("play", 0);
            }

            @Override
            public void onPause() {
                AppBridgePlugin.dispatch("pause", 0);
            }

            @Override
            public void onSkipToNext() {
                AppBridgePlugin.dispatch("next", 0);
            }

            @Override
            public void onSkipToPrevious() {
                AppBridgePlugin.dispatch("prev", 0);
            }

            @Override
            public void onSeekTo(long pos) {
                AppBridgePlugin.dispatch("seek", pos);
            }

            @Override
            public void onStop() {
                AppBridgePlugin.dispatch("pause", 0);
            }
        });
        session.setActive(true);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) {
            return START_STICKY;
        }
        String action = intent.getAction();
        if (ACTION_STOP.equals(action)) {
            abandonFocus();
            if (session != null) {
                session.setActive(false);
            }
            stopForeground(true);
            foreground = false;
            stopSelf();
            return START_NOT_STICKY;
        }
        if (ACTION_UPDATE.equals(action)) {
            applyUpdate(intent.getStringExtra(EXTRA_JSON));
            if (!foreground) {
                startForegroundCompat();
            }
            publish();
        } else if (ACTION_PLAY.equals(action)) {
            AppBridgePlugin.dispatch("play", 0);
        } else if (ACTION_PAUSE.equals(action)) {
            AppBridgePlugin.dispatch("pause", 0);
        } else if (ACTION_NEXT.equals(action)) {
            AppBridgePlugin.dispatch("next", 0);
        } else if (ACTION_PREV.equals(action)) {
            AppBridgePlugin.dispatch("prev", 0);
        } else if (ACTION_START.equals(action)) {
            startForegroundCompat();
            publish();
        }
        return START_STICKY;
    }

    private void applyUpdate(String json) {
        if (json == null) {
            return;
        }
        try {
            JSONObject o = new JSONObject(json);
            title = o.optString("title", title);
            artist = o.optString("artist", artist);
            album = o.optString("album", album);
            duration = o.optLong("duration", duration);
            position = o.optLong("position", position);
            boolean wasPlaying = playing;
            playing = o.optBoolean("playing", playing);
            speed = (float) o.optDouble("speed", speed);
            String nextArt = o.optString("artUrl", "");
            if (!nextArt.equals(artUrl)) {
                artUrl = nextArt;
                artwork = null;
                loadArtwork(nextArt);
            }
            if (playing && !wasPlaying) {
                requestFocus();
            } else if (!playing && wasPlaying) {
                abandonFocus();
            }
        } catch (Throwable t) {
            Log.w(TAG, "bad update json", t);
        }
    }

    private void loadArtwork(String url) {
        if (url == null || url.isEmpty()) {
            return;
        }
        io.execute(() -> {
            Bitmap bitmap = null;
            try {
                HttpURLConnection conn = (HttpURLConnection) new URL(url).openConnection();
                conn.setConnectTimeout(5000);
                conn.setReadTimeout(5000);
                try (InputStream in = conn.getInputStream()) {
                    bitmap = BitmapFactory.decodeStream(in);
                }
                conn.disconnect();
            } catch (Throwable t) {
                Log.w(TAG, "artwork failed", t);
            }
            Bitmap result = bitmap;
            main.post(() -> {
                if (url.equals(artUrl)) {
                    artwork = result;
                    publish();
                }
            });
        });
    }

    private void publish() {
        if (session == null) {
            return;
        }
        MediaMetadata.Builder meta = new MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, title)
            .putString(MediaMetadata.METADATA_KEY_ARTIST, artist)
            .putString(MediaMetadata.METADATA_KEY_ALBUM, album)
            .putLong(MediaMetadata.METADATA_KEY_DURATION, duration);
        if (artwork != null) {
            meta.putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, artwork);
        }
        session.setMetadata(meta.build());

        long actions = PlaybackState.ACTION_PLAY | PlaybackState.ACTION_PAUSE
            | PlaybackState.ACTION_PLAY_PAUSE | PlaybackState.ACTION_SKIP_TO_NEXT
            | PlaybackState.ACTION_SKIP_TO_PREVIOUS | PlaybackState.ACTION_SEEK_TO
            | PlaybackState.ACTION_STOP;
        PlaybackState.Builder state = new PlaybackState.Builder()
            .setActions(actions)
            .setState(playing ? PlaybackState.STATE_PLAYING : PlaybackState.STATE_PAUSED,
                position, playing ? speed : 0f);
        session.setPlaybackState(state.build());

        NotificationManager manager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        Notification notification = buildNotification();
        if (foreground) {
            manager.notify(NOTIFICATION_ID, notification);
        }
    }

    private Notification buildNotification() {
        Intent open = new Intent(this, MainActivity.class)
            .setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        PendingIntent content = PendingIntent.getActivity(this, 0, open, flags);

        Notification.Builder builder = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
            ? new Notification.Builder(this, CHANNEL_ID)
            : new Notification.Builder(this);
        builder.setSmallIcon(R.drawable.ic_stat_music)
            .setContentTitle(title.isEmpty() ? "简音" : title)
            .setContentText(artist)
            .setContentIntent(content)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(playing)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setLargeIcon(artwork)
            .setStyle(new Notification.MediaStyle()
                .setMediaSession(session.getSessionToken())
                .setShowActionsInCompactView(0, 1, 2));

        builder.addAction(new Notification.Action.Builder(android.R.drawable.ic_media_previous, "上一首",
            serviceIntent(ACTION_PREV, 1)).build());
        if (playing) {
            builder.addAction(new Notification.Action.Builder(android.R.drawable.ic_media_pause, "暂停",
                serviceIntent(ACTION_PAUSE, 2)).build());
        } else {
            builder.addAction(new Notification.Action.Builder(android.R.drawable.ic_media_play, "播放",
                serviceIntent(ACTION_PLAY, 2)).build());
        }
        builder.addAction(new Notification.Action.Builder(android.R.drawable.ic_media_next, "下一首",
            serviceIntent(ACTION_NEXT, 3)).build());
        return builder.build();
    }

    private PendingIntent serviceIntent(String action, int code) {
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        Intent intent = new Intent(this, MediaService.class).setAction(action);
        return PendingIntent.getService(this, code, intent, flags);
    }

    private void createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return;
        }
        NotificationChannel channel = new NotificationChannel(CHANNEL_ID, "播放控制",
            NotificationManager.IMPORTANCE_LOW);
        channel.setShowBadge(false);
        NotificationManager manager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        manager.createNotificationChannel(channel);
    }

    private void startForegroundCompat() {
        Notification notification = buildNotification();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
        } else {
            startForeground(NOTIFICATION_ID, notification);
        }
        foreground = true;
    }

    private void requestFocus() {
        if (audioManager == null || hasFocus) {
            return;
        }
        AudioManager.OnAudioFocusChangeListener listener = change -> {
            if (change <= AudioManager.AUDIOFOCUS_LOSS_TRANSIENT || change == AudioManager.AUDIOFOCUS_LOSS) {
                AppBridgePlugin.dispatch("pause", 0);
            }
        };
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (focusRequest == null) {
                focusRequest = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(new AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build())
                    .setOnAudioFocusChangeListener(listener)
                    .build();
            }
            hasFocus = audioManager.requestAudioFocus(focusRequest) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED;
        } else {
            hasFocus = audioManager.requestAudioFocus(listener, AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED;
        }
    }

    private void abandonFocus() {
        if (audioManager == null || !hasFocus) {
            return;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && focusRequest != null) {
            audioManager.abandonAudioFocusRequest(focusRequest);
        }
        hasFocus = false;
    }

    @Override
    public void onDestroy() {
        io.shutdown();
        if (session != null) {
            session.setActive(false);
            session.release();
            session = null;
        }
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
