/* Injected at document start, before any page script runs.
   Teaches the page that it is running inside the native app. */
(function () {
  "use strict";

  /* The page skips its browser-fullscreen dance when it thinks it is installed —
     inside the app it already owns the whole screen. */
  try {
    Object.defineProperty(window.navigator, "standalone", { value: true, configurable: true });
  } catch (e) {}

  /* Screen Wake Lock isn't implemented in WKWebView; hand the page a native one. */
  if (!("wakeLock" in navigator)) {
    var post = function (cmd) {
      try { window.webkit.messageHandlers.wake.postMessage({ cmd: cmd }); } catch (e) {}
    };
    try {
      Object.defineProperty(navigator, "wakeLock", {
        configurable: true,
        value: {
          request: function () {
            post("acquire");
            var released = false;
            return Promise.resolve({
              type: "screen",
              released: false,
              release: function () {
                if (!released) { released = true; post("release"); }
                return Promise.resolve();
              },
              addEventListener: function () {},
              removeEventListener: function () {}
            });
          }
        }
      });
    } catch (e) {}
  }

  /* localStorage normally works fine on this custom scheme. If WebKit ever hands us a
     partitioned or opaque origin, fall back to a native-backed store so a user's scripts
     are never silently lost. */
  var usable = false;
  try {
    var probe = "__vc_probe__";
    window.localStorage.setItem(probe, "1");
    window.localStorage.removeItem(probe);
    usable = true;
  } catch (e) {}

  if (!usable) {
    var data = window.__nativeSeed || {};
    var send = function (msg) {
      try { window.webkit.messageHandlers.store.postMessage(msg); } catch (e) {}
    };
    var shim = {
      getItem: function (k) { k = String(k); return Object.prototype.hasOwnProperty.call(data, k) ? data[k] : null; },
      setItem: function (k, v) { k = String(k); v = String(v); data[k] = v; send({ cmd: "set", key: k, value: v }); },
      removeItem: function (k) { k = String(k); delete data[k]; send({ cmd: "remove", key: k }); },
      clear: function () { data = {}; send({ cmd: "clear" }); },
      key: function (i) { var ks = Object.keys(data); return i < ks.length ? ks[i] : null; }
    };
    Object.defineProperty(shim, "length", { get: function () { return Object.keys(data).length; } });
    try {
      Object.defineProperty(window, "localStorage", { configurable: true, value: shim });
    } catch (e) {}
  }

  /* Controls that only make sense in a browser tab. */
  document.addEventListener("DOMContentLoaded", function () {
    ["prFull", "tglFull"].forEach(function (id) {
      var el = document.getElementById(id);
      if (el) el.style.display = "none";
    });
    var tips = document.querySelector("#library .foot-note");
    if (tips) {
      tips.innerHTML = "<strong>Voice tracking</strong> uses Apple's on-device speech recognition — " +
        "nothing you read is sent anywhere, and it keeps working in airplane mode. " +
        "Scripts are stored on this iPhone only.";
    }
  });
})();
