import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:moodiary/common/models/geo.dart';
import 'package:moodiary/common/models/github.dart';
import 'package:moodiary/common/models/hitokoto.dart';
import 'package:moodiary/common/models/hunyuan.dart';
import 'package:moodiary/common/models/image.dart';
import 'package:moodiary/common/models/weather.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/http_util.dart';
import 'package:moodiary/utils/notice_util.dart';

class Api {
  /// Chat with an OpenAI-compatible API
  static Future<Stream<String>?> chatWithOpenAI(
    String baseUrl,
    String apiKey,
    String model,
    List<Message> messages,
  ) async {
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
    final body = {
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'stream': true,
    };
    final url =
        baseUrl.endsWith('/')
            ? '${baseUrl}chat/completions'
            : '$baseUrl/chat/completions';
    return await HttpUtil().postStream(url, header: headers, data: body);
  }

  /// Chat with an Anthropic-compatible API
  static Future<Stream<String>?> chatWithAnthropic(
    String baseUrl,
    String apiKey,
    String model,
    List<Message> messages,
  ) async {
    final headers = {
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'Content-Type': 'application/json',
    };
    // Anthropic uses a different message format:
    // system prompt goes in a separate "system" field
    String? systemPrompt;
    final apiMessages = <Map<String, dynamic>>[];
    for (final msg in messages) {
      if (msg.role == 'system') {
        systemPrompt = msg.content;
      } else {
        apiMessages.add(msg.toJson());
      }
    }
    final body = <String, dynamic>{
      'model': model,
      'messages': apiMessages,
      'stream': true,
      'max_tokens': 4096,
    };
    if (systemPrompt != null) {
      body['system'] = systemPrompt;
    }
    final url =
        baseUrl.endsWith('/')
            ? '${baseUrl}messages'
            : '$baseUrl/messages';
    return await HttpUtil().postStream(url, header: headers, data: body);
  }

  static Future<Uint8List?> getImageData(String url) async {
    return (await HttpUtil().get(url, type: ResponseType.bytes)).data;
  }

  static Future<List<String>?> updatePosition(BuildContext context) async {
    Position? position;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied && context.mounted) {
        toast.info(message: context.l10n.noticeEnableLocation);
        return null;
      }
      if (permission == LocationPermission.deniedForever && context.mounted) {
        toast.info(message: context.l10n.noticeEnableLocation2);
        return null;
      }
    }
    if (await Geolocator.isLocationServiceEnabled()) {
      position = await Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: true,
      );
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(forceLocationManager: true),
      );
    }
    if (position != null && context.mounted) {
      final local = Localizations.localeOf(context);
      final parameters = {
        'location':
            '${double.parse(position.longitude.toStringAsFixed(2))},${double.parse(position.latitude.toStringAsFixed(2))}',
        'key': PrefUtil.getValue<String>('qweatherKey'),
        'lang': local,
      };
      final res = await HttpUtil().get(
        'https://${PrefUtil.getValue<String>('qweatherApiHost')}/geo/v2/city/lookup',
        parameters: parameters,
      );
      final geo = await compute(
        GeoResponse.fromJson,
        res.data as Map<String, dynamic>,
      );
      if (geo.location != null && geo.location!.isNotEmpty) {
        final city = geo.location!.first;
        return [
          position.latitude.toString(),
          position.longitude.toString(),
          '${city.adm2} ${city.name}',
        ];
      } else {
        return null;
      }
    } else {
      return null;
    }
  }

  static Future<List<String>?> updateWeather({
    required BuildContext context,
    required LatLng position,
  }) async {
    final local = Localizations.localeOf(context);
    final parameters = {
      'location':
          '${double.parse(position.longitude.toStringAsFixed(2))},${double.parse(position.latitude.toStringAsFixed(2))}',
      'key': PrefUtil.getValue<String>('qweatherKey'),
      'lang': local,
    };
    final res = await HttpUtil().get(
      'https://${PrefUtil.getValue<String>('qweatherApiHost')}/v7/weather/now',
      parameters: parameters,
    );
    final weather = await compute(
      WeatherResponse.fromJson,
      res.data as Map<String, dynamic>,
    );
    if (weather.now != null) {
      return [weather.now!.icon!, weather.now!.temp!, weather.now!.text!];
    } else {
      return null;
    }
  }

  static Future<GithubRelease?> getGithubRelease() async {
    final res = await HttpUtil().get(
      'https://api.github.com/repos/ZhuJHua/moodiary/releases/latest',
    );
    if (res.data != null) {
      final githubRelease = await compute(
        GithubRelease.fromJson,
        res.data as Map<String, dynamic>,
      );
      return githubRelease;
    }
    return null;
  }

  static Future<List<String>?> updateHitokoto() async {
    final res = await HttpUtil().get('https://v1.hitokoto.cn');
    final hitokoto = await compute(
      HitokotoResponse.fromJson,
      res.data as Map<String, dynamic>,
    );
    return [hitokoto.hitokoto!];
  }

  static Future<List<String>?> updateImageUrl() async {
    final res = await HttpUtil().get(
      'https://cn.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1',
    );
    final BingImage bingImage = await compute(
      BingImage.fromJson,
      res.data as Map<String, dynamic>,
    );
    return ['https://cn.bing.com${bingImage.images?[0].url}'];
  }
}
