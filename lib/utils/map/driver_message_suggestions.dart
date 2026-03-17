class DriverMessageSuggestions {
  DriverMessageSuggestions._();

  static List<String> pickup({
    required bool reachedPickup,
    required int etaMinutes,
  }) {
    if (reachedPickup) {
      return const <String>[
        'Driver reached pickup point',
        'Please come to pickup point',
        'Please keep OTP ready',
        'I am waiting at pickup',
      ];
    }
    if (etaMinutes >= 10) {
      return <String>[
        'Delay due to traffic, ETA $etaMinutes min',
        'Please wait at pickup point',
        'I am on the way',
        'Sorry for delay',
      ];
    }
    if (etaMinutes >= 4) {
      return <String>[
        'Reaching in $etaMinutes min',
        'Please come to pickup point',
        'Traffic little high',
        'I am nearby',
      ];
    }
    return const <String>[
      'I am nearby',
      'Reaching now',
      'Please be ready',
      'Please come to pickup point',
    ];
  }

  static List<String> drop({required int etaMinutes}) {
    if (etaMinutes >= 10) {
      return <String>[
        'Delay due to traffic, ETA $etaMinutes min',
        'Please stay available',
        'I am on the way',
        'Sorry for delay',
      ];
    }
    if (etaMinutes >= 4) {
      return <String>[
        'Reaching in $etaMinutes min',
        'Will reach soon',
        'Small delay due to traffic',
        'On route now',
      ];
    }
    return const <String>[
      'Arriving soon',
      'Almost there',
      'Please stay reachable',
      'Near your location',
    ];
  }
}
