/**
 * Drpy2 WebView 宿主（对标 BieCuiLe drpy_host.js 思路）
 * 在隐藏 WebView 中注入 TVBox/drpy 常用 API。
 * 网络请求经 Flutter Channel 异步完成，再用 Promise 包装供规则 await。
 */
(function () {
  var g = window;
  g.__nativeCallbacks = {};
  g.__cbId = 0;

  function nextId() {
    g.__cbId += 1;
    return 'cb_' + g.__cbId;
  }

  /** Flutter 回调入口 */
  g.__nativeResolve = function (id, body, error) {
    var entry = g.__nativeCallbacks[id];
    if (!entry) return;
    delete g.__nativeCallbacks[id];
    if (error) entry.reject(new Error(error));
    else entry.resolve(body);
  };

  g.__nativeSetResult = function (jsonStr) {
    try {
      g.__lastResult = JSON.parse(jsonStr);
    } catch (e) {
      g.__lastResult = jsonStr;
    }
  };

  function nativeReq(url, obj) {
    return new Promise(function (resolve, reject) {
      var id = nextId();
      g.__nativeCallbacks[id] = { resolve: resolve, reject: reject };
      obj = obj || {};
      if (window.DrpyBridge && window.DrpyBridge.postMessage) {
        window.DrpyBridge.postMessage(JSON.stringify({
          action: 'request',
          id: id,
          url: String(url),
          method: (obj.method || 'GET'),
          headers: obj.headers || {},
          body: obj.body || obj.data || null,
          timeout: obj.timeout || 15000
        }));
      } else {
        reject(new Error('DrpyBridge not ready'));
      }
    });
  }

  // 同步风格 request：多数规则写 JSON.parse(request(url))
  // WebView 里无法真正同步，提供 async 版 + 兼容包装
  g.requestAsync = function (url, obj) {
    return nativeReq(url, obj).then(function (body) {
      return typeof body === 'string' ? body : JSON.stringify(body);
    });
  };

  // 兼容旧规则：返回 Promise，规则需支持或使用 await（现代 drpy 多支持）
  g.request = function (url, obj) {
    return g.requestAsync(url, obj);
  };

  g.post = function (url, obj) {
    obj = obj || {};
    obj.method = 'POST';
    return g.request(url, obj);
  };

  g.fetch = g.request;

  g.joinUrl = function (base, url) {
    if (!url) return base || '';
    if (/^https?:\/\//i.test(url)) return url;
    if (url.indexOf('//') === 0) return 'https:' + url;
    try {
      return new URL(url, base || 'https://localhost/').href;
    } catch (e) {
      return url;
    }
  };
  g.urljoin = g.joinUrl;

  // 简化 HTML 解析
  g.pdfh = function (html, rule) {
    if (!html || !rule) return '';
    try {
      if (rule.indexOf('&&') > -1) {
        var parts = rule.split('&&');
        var tag = parts[0].trim();
        var attr = (parts[1] || 'Text').trim();
        if (attr === 'Text' || attr === 'text') {
          var re = new RegExp('<' + tag + '[^>]*>([\\s\\S]*?)</' + tag + '>', 'i');
          var m = html.match(re);
          return m ? m[1].replace(/<[^>]+>/g, '').trim() : '';
        }
        var re2 = new RegExp('<' + tag + '[^>]*' + attr + '=["\']?([^"\'\\s>]+)', 'i');
        var m2 = html.match(re2);
        return m2 ? m2[1] : '';
      }
      var m3 = html.match(new RegExp(rule, 'i'));
      return m3 ? (m3[1] || m3[0]) : '';
    } catch (e) {
      return '';
    }
  };

  g.pdfa = function (html, rule) {
    if (!html || !rule) return [];
    var list = [];
    try {
      var tag = rule.split('&&')[0].trim();
      var re = new RegExp('<' + tag + '[^>]*>[\\s\\S]*?</' + tag + '>', 'gi');
      var m;
      while ((m = re.exec(html)) !== null) list.push(m[0]);
    } catch (e) {}
    return list;
  };

  g.pd = function (html, rule, baseUrl) {
    var v = g.pdfh(html, rule);
    if (baseUrl) v = g.joinUrl(baseUrl, v);
    return v;
  };

  g.setResult = function (arr) {
    g.__lastResult = arr;
    if (window.DrpyBridge && window.DrpyBridge.postMessage) {
      window.DrpyBridge.postMessage(JSON.stringify({
        action: 'setResult',
        data: arr
      }));
    }
    return arr;
  };

  g.setHome = function (obj) {
    return g.setResult(obj);
  };

  g.print = function (msg) { console.log(String(msg)); };
  g.log = g.print;

  g.__hostReady = true;
  console.log('[DrpyHost] ready');
})();
