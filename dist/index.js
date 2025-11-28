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
      main: function(event2) {
        var click, el, func, href, hxNode, hxTarget, i, klass, len, node, ref;
        if (node = event2.target.closest("*[click], *[href]")) {
          event2.stopPropagation();
          event2.preventDefault();
          if (click = node.getAttribute("click")) {
            return new Function(click).bind(node)();
          } else {
            href = node.getAttribute("href");
            if (hxTarget = node.getAttribute("hx-target")) {
              if (hxNode = document.querySelectorAll(hxTarget)[0]) {
                Pjax.load(href, {
                  target: hxNode
                });
                return;
              }
            }
            if (href.slice(0, 2) === "//") {
              href = href.replace("/", "");
              return window.open(href);
            }
            if (event2.which === 2 || event2.metaKey) {
              return window.open(href);
            }
            klass = " " + node.className + " ";
            ref = Pjax.config.no_pjax_class;
            for (i = 0, len = ref.length; i < len; i++) {
              el = ref[i];
              if (klass.includes(` ${el} `)) {
                if (/^http/.test(href)) {
                  window.open(href);
                } else {
                  return window.location.href = href;
                }
              }
            }
            if (/^javascript:/.test(href)) {
              func = new Function(href.replace(/^javascript:/, ""));
              return func();
            }
            if (/^\w/.test(href) || node.getAttribute("target")) {
              return window.open(href, node.getAttribute("target") || href.replace(/[^\w]/g, ""));
            }
            if (/^\/\//.test(href)) {
              return window.open(window.location.origin + href.replace("/", ""), node.getAttribute("target") || href.replace(/[^\w]/g, ""));
            }
            Pjax.load(href, {
              ajax: node
            });
            return false;
          }
        }
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
    var import_onclick = __toESM(require_onclick());
    var Pjax3;
    Pjax3 = function() {
      class Pjax4 {
        // you have to call this if you want to capture clicks on document level
        // Example: Pjax.onDocumentClick()
        static onDocumentClick() {
          return document.addEventListener("click", import_onclick.default.main);
        }
        // base class method to load page
        // istory: bool
        // scroll: bool
        // cache: bool
        // done: ()=>{...}
        static load(href, opts) {
          opts = this.getOpts(href, opts);
          return this.fetch(opts);
        }
        // refresh page, keep scroll
        static refresh(func, opts) {
          if (typeof func === "string" && func[0] === "#") {
            opts || (opts = {});
            opts.target = func;
            func = Pjax4.path();
            opts.history = false;
          }
          opts = this.getOpts(func, opts);
          opts.scroll || (opts.scroll = false);
          return this.fetch(opts);
        }
        // reload, jump to top, no_cache http request forced
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
        // normalize options
        static getOpts(path, opts) {
          var ajax_node, ajax_path, el, i, key, len, ref, ref1, skip_ajax, value;
          opts || (opts = {});
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
          if (opts.ajax) {
            opts.node = opts.ajax;
            if (typeof opts.node === "string") {
              opts.node = document.querySelector(opts.node);
            }
            skip_ajax = false;
            ref1 = this.config.no_ajax_class;
            for (i = 0, len = ref1.length; i < len; i++) {
              el = ref1[i];
              if (opts.ajax.closest(`.${el}`)) {
                skip_ajax = true;
              }
            }
            if (!skip_ajax) {
              if (ajax_node = opts.node.closest(Pjax4.config.ajax_selector)) {
                opts.ajax_node = ajax_node;
                opts.scroll || (opts.scroll = false);
              }
            }
            delete opts.ajax;
          }
          if (opts.target) {
            if (typeof opts.target === "string") {
              opts.target = document.querySelectorAll(opts.target)[0];
            }
            opts.node = opts.target;
            opts.scroll || (opts.scroll = false);
          }
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
          if (opts.replacePath) {
            if (opts.replacePath[0] === "?") {
              opts.replacePath = location.pathname + path;
            }
          }
          return opts;
        }
        static fetch(opts) {
          var pjax;
          pjax = new Pjax4(opts);
          return pjax.load();
        }
        // used to get full page path
        static path() {
          return location.pathname + location.search;
        }
        static node() {
          var el;
          el = document.getElementsByTagName("pjax")[0] || document.getElementsByClassName("pjax")[0] || alert(".pjax or #pjax not found");
          if (el.nodeName === "BODY") {
            alert("You cant bind PJAX to body");
          }
          return el;
        }
        static console(msg) {
          if (!this.config.is_silent) {
            return console.log(msg);
          }
        }
        // execute action before pjax load and do not proceed if return is false
        // example, load dialog links inside the dialog
        // Pjax.before (href, opts) ->
        //   if opts.node
        //     if opts.node.closest('.in-popup')
        //       Dialog.load href
        //       return false
        //   true
        static before() {
          return true;
        }
        // execute action after pjax load
        static after() {
          return true;
        }
        // error logger, replace as fitting
        static error(msg) {
          return console.error(`Pjax error: ${msg}`);
        }
        static parseSingleScript(id, img) {
          var func, node;
          img.remove();
          if (node = document.getElementById(id)) {
            func = new Function(node.innerText);
            func();
            return node.text = 1;
          }
        }
        static parseScripts(node) {
          var duplicate, func, i, len, ref, script_tag, type;
          if (typeof node === "string") {
            duplicate = node;
            node = document.createElement("div");
            node.innerHTML = duplicate;
          }
          ref = node.getElementsByTagName("script");
          for (i = 0, len = ref.length; i < len; i++) {
            script_tag = ref[i];
            if (script_tag) {
              if (!script_tag.getAttribute("src")) {
                type = script_tag.getAttribute("type") || "javascript";
                if (type.indexOf("javascript") > -1) {
                  if (!script_tag.id) {
                    this.script_cnt || (this.script_cnt = 0);
                    script_tag.id = `app-sc-${++this.script_cnt}`;
                  }
                  func = new Function(script_tag.textContent);
                  func();
                  script_tag.text = 1;
                }
              }
            }
          }
          return node.innerHTML;
        }
        // internal
        static noScrollCheck(node) {
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
        static last() {
          return this.lastHref || this.path();
        }
        static sendGlobalEvent() {
          return document.dispatchEvent(new CustomEvent("pjax:render"));
        }
        static pushState(href) {
          return window.history.pushState({}, document.title, href);
        }
        static push(href) {
          return this.pushState(href);
        }
        // locks page scrolling to prevent jump to top of the page on refresh
        static scrollLock(opts = {}) {
          var body, now, scrollPosition;
          now = Date.now();
          if (this._scrollLockTime && now - this._scrollLockTime < 1e3) {
            return;
          }
          this._scrollLockTime = now;
          scrollPosition = window.pageYOffset;
          body = document.body;
          body.style.height = window.getComputedStyle(body).height;
          window.scrollTo(0, scrollPosition);
          return window.requestAnimationFrame(() => {
            body.style.height = "";
            return window.scrollTo(0, scrollPosition);
          });
        }
        // prevert page flicker on refresh by fixing main node height
        static setPageBody(node, href) {
          var new_body, pjaxNode, ref, title;
          title = (ref = node.querySelector("title")) != null ? ref.innerHTML : void 0;
          document.title = title || "no page title (pjax)";
          Pjax4.scrollLock();
          pjaxNode = Pjax4.node();
          if (new_body = node.querySelector("#" + pjaxNode.id)) {
            if (Pjax4.useViewTransition && document.startViewTransition) {
              document.startViewTransition(() => {
                return pjaxNode.innerHTML = Pjax4.parseScripts(new_body);
              });
            } else {
              pjaxNode.innerHTML = Pjax4.parseScripts(new_body);
            }
            Pjax4.after(href, this.opts);
            return Pjax4.sendGlobalEvent();
          }
        }
        // sets or adds value to querystring
        // Pjax.qs('place', el.name, { push: true })
        static qs(key, value, opts = {}) {
          var data, href, parts, qs;
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
            qs[key] = encodeURIComponent(value);
            data = Object.keys(qs).map((key2) => {
              return `${key2}=${qs[key2]}`;
            }).join("&");
            href = location.pathname + "?" + data;
            if (opts.push) {
              if (opts.push) {
                window.history.pushState({}, document.title, href);
              }
              if (!opts.mock) {
                return Pjax4.push(href);
              }
            } else if (opts.href) {
              return href;
            } else {
              return Pjax4.load(href);
            }
          }
        }
        constructor(opts1) {
          this.opts = opts1;
          this.href = this.opts.href || this.opts.path;
        }
        redirect() {
          this.href || (this.href = location.href);
          if (this.href[0] === "h" && !this.href.includes(location.host)) {
            window.open(this.href);
          } else {
            location.href = this.href;
          }
          return false;
        }
        // load a new page
        load() {
          var el, headers, i, k, len, node, ref, v;
          if (!this.href) {
            return false;
          }
          Pjax4.pastHref = Pjax4.lastHref;
          Pjax4.lastHref = this.href;
          if (event && !event.key && (event.which === 2 || event.metaKey)) {
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
          this.opts.req_start_time = (/* @__PURE__ */ new Date()).getTime();
          this.opts.path = this.href;
          headers = {};
          if (this.opts.cache === false) {
            headers["cache-control"] = "no-cache";
          }
          headers["x-requested-with"] = "XMLHttpRequest";
          if (Pjax4.request) {
            Pjax4.request.abort();
          }
          Pjax4.request = this.req = new XMLHttpRequest();
          this.req.onerror = function(e) {
            Pjax4.error("Net error: Server response not received (Pjax)");
            return console.error(e);
          };
          this.req.open("GET", this.href);
          for (k in headers) {
            v = headers[k];
            this.req.setRequestHeader(k, v);
          }
          this.req.onload = (e) => {
            var log_data, rul, time_diff;
            this.response = this.req.responseText;
            time_diff = (/* @__PURE__ */ new Date()).getTime() - this.opts.req_start_time;
            log_data = `Pjax.load ${this.href}`;
            log_data += this.opts.history === false ? " (back trigger)" : "";
            Pjax4.console(`${log_data} (app ${this.req.getResponseHeader("x-lux-speed") || "n/a"}, real ${time_diff}ms, status ${this.req.status})`);
            if (this.req.status !== 200) {
              return this.redirect();
            } else {
              if (rul = this.req.responseURL) {
                this.href = rul.split("/");
                this.href.splice(0, 3);
                this.href = "/" + this.href.join("/");
              }
              if (this.applyLoadedData()) {
                if (typeof this.opts.done === "function") {
                  this.opts.done();
                }
                if (!(this.opts.scroll === false || Pjax4.noScrollCheck(this.opts.node))) {
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
              } else {
                return this.redirect();
              }
            }
          };
          this.req.send();
          return false;
        }
        applyLoadedData() {
          var ajax_data, ajax_id, ajax_node, id, ref, rtarget;
          this.pjaxNode = Pjax4.node();
          if (!this.pjaxNode) {
            Pjax4.error("template_id mismatch, full page load (use no-pjax as a class name)");
            return;
          }
          if (!this.pjaxNode.id) {
            alert("No ID attribute on pjax node");
            return;
          }
          this.historyAddCurrent(this.opts.replacePath || this.href);
          this.rroot = document.createElement("div");
          this.rroot.innerHTML = this.response;
          if (this.opts.target) {
            if (id = this.opts.target.getAttribute("id")) {
              rtarget = this.rroot.querySelector("#" + id);
              if (rtarget) {
                Pjax4.scrollLock();
                this.opts.target.innerHTML = Pjax4.parseScripts(rtarget.innerHTML);
                return true;
              }
            } else {
              alert("ID attribute not found on Pjax target");
            }
          }
          if (ajax_node = this.opts.ajax_node) {
            ajax_node.setAttribute("data-path", this.href);
            ajax_node.removeAttribute("path");
            ajax_id = ajax_node.getAttribute("id") || alert("Pjax .ajax node has no ID");
            ajax_data = ((ref = this.rroot.querySelector("#" + ajax_id)) != null ? ref.innerHTML : void 0) || this.response;
            ajax_node.innerHTML = Pjax4.parseScripts(ajax_data);
            return true;
          }
          Pjax4.historyData[Pjax4.path()] = this.response;
          return Pjax4.setPageBody(this.rroot, this.href);
        }
        // private
        // add current page to history
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
        // shoud Pjax log info to console
        is_silent: parseInt(location.port) < 1e3,
        // do not scroll to top, use refresh() and not reload() on node with selectors
        no_scroll_selector: [".no-scroll"],
        // skip pjax on followin links and do location.href = target
        // you can add function, regexp of string (checks for starts with)
        paths_to_skip: [],
        // if link has any of this classes, Pjax will be skipped and link will be followed
        // Example: %a.direct{ href '/somewhere' } somewhere
        no_pjax_class: ["no-pjax", "direct"],
        no_ajax_class: ["ajax-skip", "skip-ajax", "no-ajax", "top"],
        // if parent id found with ths class, ajax response data will be loaded in this class
        // you can add ID for better targeting. If no ID given to .ajax class
        //  * if response contains .ajax, first node found will be selected and it innerHTML will be used for replacement
        //  * if there is no .ajax in response, full page response will be used
        // Example: all links in "some_template" will refresh ".ajax" block only
        // .ajax
        //   = render 'some_template'
        ajax_selector: ".ajax"
      };
      Pjax4.historyData = {};
      return Pjax4;
    }.call(exports);
    window.onpopstate = function(event2) {
      return window.requestAnimationFrame(function() {
        var hdata, path, rroot;
        path = Pjax3.path();
        if (hdata = Pjax3.historyData[path]) {
          console.log(`from history: ${path}`);
          rroot = document.createElement("div");
          rroot.innerHTML = hdata;
          return Pjax3.setPageBody(rroot, path);
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
        var form, is_pjax, target;
        form = e.target;
        if (is_pjax = form.getAttribute("data-pjax")) {
          e.preventDefault();
          target = is_pjax === "true" ? null : target;
          return Pjax3.load(form.getAttribute("action"), {
            form,
            target
          });
        }
      }, {
        once: true
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
export {
  src_default as default
};
//# sourceMappingURL=index.js.map
