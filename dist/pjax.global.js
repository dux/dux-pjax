var Pjax;
(() => {
  var __create = Object.create;
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __getProtoOf = Object.getPrototypeOf;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __commonJS = (cb, mod) => function __require() {
    return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
    // If the importer is in node compatibility mode or this is not an ESM
    // file that has been converted to a CommonJS file using a Babel-
    // compatible transform (i.e. "__esModule" has not been set), then set
    // "default" to the CommonJS "module.exports" for node compatibility.
    isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
    mod
  ));

  // src/onclick.coffee
  var require_onclick = __commonJS({
    "src/onclick.coffee"(exports, module) {
      var PjaxOnClick;
      PjaxOnClick = {
        main: function(event) {
          var click, el, href, hxNode, hxTarget, i, len, node, ref;
          node = event.target.closest('*[click]:not([click=""]), *[href]:not([href=""])');
          if (!node) {
            return;
          }
          event.stopPropagation();
          event.preventDefault();
          if (click = node.getAttribute("click")) {
            return new Function(click).bind(node)();
          }
          href = node.getAttribute("href");
          if (hxTarget = node.getAttribute("hx-target")) {
            if (hxNode = document.querySelector(hxTarget)) {
              Pjax.load(href, {
                target: hxNode
              });
              return;
            }
          }
          if (href.slice(0, 2) === "//") {
            href = href.replace("/", "");
            return window.open(window.location.origin + href, node.getAttribute("target") || href.replace(/[^\w]/g, ""));
          }
          if (event.which === 2 || event.metaKey) {
            return window.open(href);
          }
          ref = Pjax.config.no_pjax_class;
          for (i = 0, len = ref.length; i < len; i++) {
            el = ref[i];
            if (node.classList.contains(el)) {
              if (/^http/.test(href)) {
                return window.open(href);
              } else {
                return window.location.href = href;
              }
            }
          }
          if (/^javascript:/.test(href)) {
            return new Function(href.replace(/^javascript:/, ""))();
          }
          if (/^\w/.test(href) || node.getAttribute("target")) {
            if (/^vscode:/.test(href)) {
              return window.location.href = href;
            }
            return window.open(href, node.getAttribute("target") || href.replace(/[^\w]/g, ""));
          }
          Pjax.load(href, {
            ajax: node
          });
          return false;
        }
      };
      if (typeof module !== "undefined" && module.exports) {
        module.exports = PjaxOnClick;
      }
    }
  });

  // src/pjax.coffee
  var require_pjax = __commonJS({
    "src/pjax.coffee"(exports, module) {
      var Pjax3;
      var PjaxOnClick;
      PjaxOnClick = require_onclick();
      Pjax3 = function() {
        class Pjax4 {
          // --- public class methods ---
          static onDocumentClick() {
            if (!this._clickBound) {
              this._clickBound = true;
              return window.addEventListener("click", PjaxOnClick.main);
            }
          }
          static load(href, opts) {
            return this.fetch(this.getOpts(href, opts));
          }
          static refresh(func, opts) {
            if (typeof func === "string" && func[0] === "#") {
              opts || (opts = {});
              opts.target = func;
              func = this.path();
              opts.history = false;
            }
            opts = this.getOpts(func, opts);
            opts.scroll || (opts.scroll = false);
            return this.fetch(opts);
          }
          static reload(opts) {
            opts = this.getOpts(opts);
            opts.cache || (opts.cache = false);
            return this.fetch(opts);
          }
          static refreshed() {
            if (!this.pastHref) {
              return false;
            }
            return this.pastHref === this.lastHref;
          }
          static path() {
            return location.pathname + location.search;
          }
          static last() {
            return this.lastHref || this.path();
          }
          static node() {
            var el;
            el = document.getElementsByTagName("pjax")[0] || document.getElementsByClassName("pjax")[0];
            if (!el) {
              this.error(".pjax or <pjax> not found");
              return;
            }
            if (el.nodeName === "BODY") {
              this.error("You cant bind PJAX to body");
              return;
            }
            return el;
          }
          static console(msg) {
            if (!this.config.is_silent) {
              return console.log(msg);
            }
          }
          static before() {
            return true;
          }
          static after() {
            return true;
          }
          static error(msg) {
            return console.error(`Pjax error: ${msg}`);
          }
          static push(href) {
            return window.history.pushState({}, document.title, href);
          }
          static pushState(href) {
            return this.push(href);
          }
          static replace(href) {
            return window.history.replaceState({}, document.title, href);
          }
          static sendGlobalEvent() {
            return document.dispatchEvent(new CustomEvent("pjax:render"));
          }
          // --- option normalization ---
          static getOpts(path, opts) {
            opts = this._resolveArgs(path, opts);
            if (opts.ajax) {
              this._resolveAjax(opts);
            }
            if (opts.target) {
              this._resolveTarget(opts);
            }
            this._resolvePath(opts);
            return opts;
          }
          static _resolveArgs(path, opts) {
            var key, ref, value;
            opts || (opts = {});
            if (typeof opts === "string") {
              opts = {
                target: opts
              };
            }
            if (typeof path === "object") {
              if (path.nodeName) {
                opts.ajax = path;
              } else {
                opts = path;
              }
            } else if (typeof path === "function") {
              opts.done = path;
            } else {
              opts.path = path;
            }
            if (opts.href) {
              opts.path = opts.href;
              delete opts.href;
            }
            opts.path || (opts.path = this.path());
            if (opts.form) {
              ref = Z(opts.form).serializeHash();
              for (key in ref) {
                value = ref[key];
                opts.path += opts.path.includes("?") ? "&" : "?";
                opts.path += `${key}=${encodeURIComponent(value)}`;
              }
            }
            return opts;
          }
          static _resolveAjax(opts) {
            var ajax_node, el, i, len, ref, skip;
            opts.node = opts.ajax;
            if (typeof opts.node === "string") {
              opts.node = document.querySelector(opts.node);
            }
            skip = false;
            ref = this.config.no_ajax_class;
            for (i = 0, len = ref.length; i < len; i++) {
              el = ref[i];
              if (opts.ajax.closest(`.${el}`)) {
                skip = true;
              }
            }
            if (!skip) {
              if (ajax_node = opts.node.closest(this.config.ajax_selector)) {
                opts.ajax_node = ajax_node;
                opts.scroll || (opts.scroll = false);
              }
            }
            return delete opts.ajax;
          }
          static _resolveTarget(opts) {
            if (typeof opts.target === "string") {
              opts.target = document.querySelector(opts.target);
            }
            opts.node = opts.target;
            return opts.scroll || (opts.scroll = false);
          }
          static _resolvePath(opts) {
            var ajax_path;
            if (opts.path[0] === "?") {
              if (opts.ajax_node) {
                ajax_path = opts.ajax_node.getAttribute("data-path") || opts.ajax_node.getAttribute("path");
                if (ajax_path) {
                  opts.path = ajax_path.split("?")[0] + opts.path;
                }
              }
              if (opts.path[0] === "?") {
                opts.path = location.pathname + opts.path;
              }
            }
            if (opts.replacePath && opts.replacePath[0] === "?") {
              return opts.replacePath = location.pathname + opts.replacePath;
            }
          }
          // --- scroll management ---
          static shouldSkipScroll(node) {
            var el, i, len, ref;
            if (!(node && node.closest)) {
              return;
            }
            ref = this.config.no_scroll_selector;
            for (i = 0, len = ref.length; i < len; i++) {
              el = ref[i];
              if (node.closest(el)) {
                return true;
              }
            }
            return false;
          }
          static scrollLock() {
            var body, now, scrollPosition;
            now = Date.now();
            if (this._scrollLockTime && now - this._scrollLockTime < 1e3) {
              return;
            }
            this._scrollLockTime = now;
            scrollPosition = window.scrollY;
            body = document.body;
            body.style.height = window.getComputedStyle(body).height;
            window.scrollTo(0, scrollPosition);
            return window.requestAnimationFrame(() => {
              body.style.height = "";
              return window.scrollTo(0, scrollPosition);
            });
          }
          // --- page rendering ---
          static setPageBody(node, href) {
            var new_body, pjaxNode, ref, title;
            title = (ref = node.querySelector("title")) != null ? ref.innerHTML : void 0;
            document.title = title || "no page title (pjax)";
            this.scrollLock();
            pjaxNode = this.node();
            if (!pjaxNode) {
              return;
            }
            if (new_body = node.querySelector("#" + pjaxNode.id)) {
              if (this.useViewTransition && document.startViewTransition) {
                document.startViewTransition(() => {
                  return this.morphInto(pjaxNode, this.parseScripts(new_body));
                });
              } else {
                this.morphInto(pjaxNode, this.parseScripts(new_body));
              }
              this.after(href, this.opts);
              return this.sendGlobalEvent();
            }
          }
          static morphInto(target, html) {
            var ref;
            if ((ref = window.Fez) != null ? ref.nodeMorph : void 0) {
              return window.Fez.nodeMorph(target, html);
            } else {
              return target.innerHTML = html;
            }
          }
          static parseSingleScript(id, img) {
            var node;
            img.remove();
            if (node = document.getElementById(id)) {
              new Function(node.textContent)();
              return node.text = 1;
            }
          }
          static parseScripts(node) {
            var div, func, i, len, ref, script_tag, type;
            if (typeof node === "string") {
              div = document.createElement("div");
              div.innerHTML = node;
              node = div;
            }
            ref = node.getElementsByTagName("script");
            for (i = 0, len = ref.length; i < len; i++) {
              script_tag = ref[i];
              if (!script_tag) {
                continue;
              }
              if (script_tag.getAttribute("src")) {
                continue;
              }
              type = script_tag.getAttribute("type") || "javascript";
              if (!type.includes("javascript")) {
                continue;
              }
              if (!script_tag.id) {
                this.script_cnt || (this.script_cnt = 0);
                script_tag.id = `app-sc-${++this.script_cnt}`;
              }
              func = new Function(script_tag.textContent);
              script_tag.text = 1;
              if (script_tag.getAttribute("delay")) {
                requestAnimationFrame(func);
              } else {
                func();
              }
            }
            return node.innerHTML;
          }
          // --- querystring helper ---
          static qs(key, value, opts = {}) {
            var data, href, parts, qs, remaining;
            parts = location.search.replace(/^\?/, "").split("&").map(function(el) {
              return el.split("=", 2);
            });
            if (typeof value === "undefined") {
              parts.forEach(function(el) {
                if (el[0] === key) {
                  return value = decodeURIComponent(el[1]);
                }
              });
              return value;
            } else {
              qs = {};
              parts.forEach(function(el) {
                if (el[0]) {
                  return qs[el[0]] = el[1];
                }
              });
              if (value === null || value === false) {
                delete qs[key];
              } else {
                qs[key] = encodeURIComponent(value);
              }
              remaining = Object.keys(qs);
              if (remaining.length) {
                data = remaining.map((k) => {
                  return `${k}=${qs[k]}`;
                }).join("&");
                href = location.pathname + "?" + data;
              } else {
                href = location.pathname;
              }
              if (opts.push) {
                if (!opts.mock) {
                  return this.push(href);
                }
              } else if (opts.href) {
                return href;
              } else {
                return this.load(href);
              }
            }
          }
          // --- history management ---
          static _addHistoryEntry(html) {
            var keys, max;
            keys = Object.keys(this.historyData);
            max = this.config.history_max || 20;
            if (keys.length >= max) {
              delete this.historyData[keys[0]];
            }
            return this.historyData[this.path()] = {
              html,
              scrollY: 0
            };
          }
          // --- internal ---
          static fetch(opts) {
            var pjax;
            pjax = new Pjax4(opts);
            return pjax.load();
          }
          // --- instance methods ---
          constructor(opts1) {
            this.opts = opts1;
            this.href = this.opts.href || this.opts.path;
          }
          redirect() {
            this.href || (this.href = location.href);
            if (this.href.slice(0, 4) === "http" && !this.href.includes(location.host)) {
              window.open(this.href);
            } else {
              location.href = this.href;
            }
            return false;
          }
          load() {
            var currentEntry, e, el, i, len, node, now, ref;
            if (!this.href) {
              return false;
            }
            now = Date.now();
            if (Pjax4.lastHref === this.href && now - (Pjax4._lastLoadTime || 0) < 2e3) {
              return false;
            }
            Pjax4._lastLoadTime = now;
            currentEntry = Pjax4.historyData[Pjax4.path()];
            if (currentEntry) {
              currentEntry.scrollY = window.scrollY;
            }
            Pjax4.pastHref = Pjax4.lastHref;
            Pjax4.lastHref = this.href;
            e = window.event;
            if (e && !e.key && (e.which === 2 || e.metaKey)) {
              return window.open(this.href);
            }
            if (Pjax4.before(this.href, this.opts) === false) {
              return;
            }
            if (location.hash && location.pathname === this.href) {
              return;
            }
            if (this.href.startsWith("#")) {
              if (this.href === "#") {
                return;
              }
              if (node = document.querySelector(`a[name=${this.href.replace("#", "")}]`)) {
                node.scrollIntoView({
                  behavior: "smooth",
                  block: "start"
                });
                return false;
              }
            }
            if (/^http/.test(this.href) || /#/.test(this.href) || this.is_disabled) {
              return this.redirect();
            }
            ref = Pjax4.config.paths_to_skip;
            for (i = 0, len = ref.length; i < len; i++) {
              el = ref[i];
              switch (typeof el) {
                case "object":
                  if (el.test(this.href)) {
                    return this.redirect();
                  }
                  break;
                case "function":
                  if (el(this.href)) {
                    return this.redirect();
                  }
                  break;
                default:
                  if (this.href.startsWith(el)) {
                    return this.redirect();
                  }
              }
            }
            if (Pjax4.request) {
              Pjax4.request.abort();
            }
            this.sendRequest();
            return false;
          }
          sendRequest() {
            var headers, k, v;
            document.dispatchEvent(new CustomEvent("pjax:start"));
            this.opts.req_start_time = Date.now();
            this.opts.path = this.href;
            headers = {
              "x-requested-with": "XMLHttpRequest"
            };
            if (this.opts.cache === false) {
              headers["cache-control"] = "no-cache";
            }
            Pjax4.request = this.req = new XMLHttpRequest();
            this.req.timeout = Pjax4.config.timeout || 1e4;
            this.req.onerror = function(e) {
              Pjax4.error("Net error: Server response not received (Pjax)");
              return console.error(e);
            };
            this.req.ontimeout = () => {
              Pjax4.request = null;
              Pjax4.error(`Request timeout: ${this.href}`);
              return this.redirect();
            };
            this.req.open("GET", this.href);
            for (k in headers) {
              v = headers[k];
              this.req.setRequestHeader(k, v);
            }
            this.req.onload = () => {
              return this.handleResponse();
            };
            return this.req.send();
          }
          handleResponse() {
            var log_data, parsed, rul, time_diff;
            Pjax4.request = null;
            this.response = this.req.responseText;
            time_diff = Date.now() - this.opts.req_start_time;
            log_data = `Pjax.load ${this.href}`;
            if (this.opts.history === false) {
              log_data += " (back trigger)";
            }
            Pjax4.console(`${log_data} (app ${this.req.getResponseHeader("x-lux-speed") || "n/a"}, real ${time_diff}ms, status ${this.req.status})`);
            if (this.req.status !== 200) {
              return this.redirect();
            }
            if (rul = this.req.responseURL) {
              parsed = new URL(rul);
              this.href = parsed.pathname + parsed.search;
            }
            if (!this.applyLoadedData()) {
              return this.redirect();
            }
            if (typeof this.opts.done === "function") {
              this.opts.done();
            }
            if (!(this.opts.scroll === false || Pjax4.shouldSkipScroll(this.opts.node))) {
              return window.requestAnimationFrame(function() {
                return window.scrollTo({
                  top: 0,
                  left: 0,
                  behavior: "smooth"
                });
              });
            } else {
              return Pjax4.scrollLock();
            }
          }
          applyLoadedData() {
            this.pjaxNode = Pjax4.node();
            if (!this.pjaxNode) {
              return;
            }
            if (!this.pjaxNode.id) {
              return Pjax4.error("No ID attribute on pjax node");
            }
            this.historyAddCurrent(this.opts.replacePath || this.href);
            this.rroot = document.createElement("div");
            this.rroot.innerHTML = this.response;
            if (this.opts.target && this.applyTarget()) {
              return true;
            }
            if (this.opts.ajax_node) {
              return this.applyAjax();
            }
            return this.applyFullSwap();
          }
          applyTarget() {
            var id, rtarget;
            id = this.opts.target.getAttribute("id");
            if (!id) {
              Pjax4.error("ID attribute not found on Pjax target");
              return false;
            }
            rtarget = this.rroot.querySelector("#" + id);
            if (!rtarget) {
              return false;
            }
            Pjax4.scrollLock();
            Pjax4.morphInto(this.opts.target, Pjax4.parseScripts(rtarget.innerHTML));
            return true;
          }
          applyAjax() {
            var ajax_data, ajax_id, ajax_node, ref;
            ajax_node = this.opts.ajax_node;
            ajax_node.setAttribute("data-path", this.href);
            ajax_node.removeAttribute("path");
            ajax_id = ajax_node.getAttribute("id") || Pjax4.error("Pjax .ajax node has no ID");
            ajax_data = ((ref = this.rroot.querySelector("#" + ajax_id)) != null ? ref.innerHTML : void 0) || this.response;
            Pjax4.morphInto(ajax_node, Pjax4.parseScripts(ajax_data));
            return true;
          }
          applyFullSwap() {
            Pjax4._addHistoryEntry(this.response);
            return Pjax4.setPageBody(this.rroot, this.href);
          }
          historyAddCurrent(href) {
            if (this.opts.history === false || this.opts.ajax_node && !this.opts.target) {
              return;
            }
            if (this.history_added) {
              return;
            }
            this.history_added = true;
            if (Pjax4._lastHrefCheck === href) {
              return window.history.replaceState({}, document.title, href);
            } else {
              window.history.pushState({}, document.title, href);
              return Pjax4._lastHrefCheck = href;
            }
          }
        }
        ;
        Pjax4.config = {
          is_silent: !location.port || parseInt(location.port) < 1e3,
          no_scroll_selector: [".no-scroll"],
          paths_to_skip: [],
          no_pjax_class: ["no-pjax", "direct"],
          no_ajax_class: ["ajax-skip", "skip-ajax", "no-ajax", "top"],
          ajax_selector: ".ajax",
          timeout: 1e4,
          history_max: 20
        };
        Pjax4.historyData = {};
        return Pjax4;
      }.call(exports);
      window.onpopstate = function(event) {
        return window.requestAnimationFrame(function() {
          var entry, path, rroot;
          path = Pjax3.path();
          if (entry = Pjax3.historyData[path]) {
            Pjax3.console(`from history: ${path}`);
            rroot = document.createElement("div");
            rroot.innerHTML = entry.html;
            Pjax3.setPageBody(rroot, path);
            if (entry.scrollY) {
              return window.scrollTo(0, entry.scrollY);
            }
          } else {
            return Pjax3.load(path, {
              history: false
            });
          }
        });
      };
      window.addEventListener("DOMContentLoaded", function() {
        setTimeout(Pjax3.sendGlobalEvent, 0);
        return document.body.addEventListener("submit", function(e) {
          var form, is_pjax, pjax_target;
          form = e.target;
          if (is_pjax = form.getAttribute("data-pjax")) {
            e.preventDefault();
            pjax_target = is_pjax === "true" ? null : is_pjax;
            return Pjax3.load(form.getAttribute("action"), {
              form,
              target: pjax_target
            });
          }
        });
      });
      if (typeof module !== "undefined" && module.exports) {
        module.exports = Pjax3;
      }
      window.Pjax = Pjax3;
    }
  });

  // src/index.js
  var import_pjax = __toESM(require_pjax());
  if (typeof window !== "undefined") {
    window.Pjax = import_pjax.default;
  }
  var src_default = import_pjax.default;
})();
if (typeof window !== "undefined") Pjax = window.Pjax;
//# sourceMappingURL=pjax.global.js.map
