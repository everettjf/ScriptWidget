/* ScriptWidget parity prelude: prepended to every corpus entry by both
   BrowserPreviewParityTests.swift and the web engine so trees are
   deterministic. It fixes the clock and randomness and replaces host-data
   APIs with identical fixed values. It is test-only, never product code. */
;(function () {
  var fixed = 1767268800000;
  var RealDate = Date;
  function ParityDate() {
    if (!new.target) return new RealDate(fixed).toString();
    if (arguments.length === 0) return new RealDate(fixed);
    return new (Function.prototype.bind.apply(RealDate, [null].concat(Array.prototype.slice.call(arguments))))();
  }
  ParityDate.prototype = RealDate.prototype;
  ParityDate.now = function () { return fixed; };
  ParityDate.UTC = RealDate.UTC;
  ParityDate.parse = RealDate.parse;
  Date = ParityDate;
  var seed = 42;
  Math.random = function () { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
  $device = {
    screen: function () { return { width: 390, height: 844, scale: 3 }; },
    language: function () { return "en"; },
    model: function () { return "iPhone"; },
    name: function () { return "iPhone"; },
    battery: function () { return { level: 0.8, state: "unplugged" }; },
    systemVersion: function () { return "26.0"; },
    isdarkmode: function () { return false; },
    totalDiskSpace: function () { return 128000000000; },
    freeDiskSpace: function () { return 64000000000; }
  };
  $system = {
    appInfo: function () { return { name: "ScriptWidget", bundleId: "com.everettjf.scriptwidget", version: "1", build: "1" }; },
    locale: function () { return "en_US"; },
    preferredLanguages: function () { return ["en-US"]; },
    timeZone: function () { return { identifier: "UTC", abbreviation: "GMT", offsetSeconds: 0 }; },
    is24HourClock: function () { return false; },
    calendarInfo: function () { return { identifier: "gregorian", firstWeekday: 1, minimumDaysInFirstWeek: 1 }; },
    systemUptime: function () { return 3600; },
    memory: function () { return { physical: 8589934592 }; },
    thermalState: function () { return "nominal"; },
    lowPowerMode: function () { return false; },
    brightness: function () { return 0.5; },
    reduceMotionEnabled: function () { return false; },
    platform: function () { return "ios"; },
    hostName: function () { return "iPhone"; },
    processName: function () { return "ScriptWidgetWidget"; },
    osVersionString: function () { return "Version 26.0"; },
    processorCount: function () { return 6; },
    activeProcessorCount: function () { return 6; }
  };
})();
