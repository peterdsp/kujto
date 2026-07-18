/* Kujto Studio, instant language switch with a crossfade.
   Progressive enhancement: the EN/SQ/EL links are real hrefs to the
   /sq/ and /el/ pages and work without JavaScript. When JS is on, a tap
   swaps the page content in place (no full reload, the target language is
   prefetched on load) and animates the change with a crossfade via the
   View Transitions API, falling back to a simple opacity fade. */
(function () {
  'use strict';

  if (!('fetch' in window) || !window.history || !window.DOMParser) return;

  var cache = Object.create(null);
  var reduceMotion = window.matchMedia &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function load(href) {
    if (cache[href]) return Promise.resolve(cache[href]);
    return fetch(href, { credentials: 'same-origin' })
      .then(function (r) {
        if (!r.ok) throw new Error('HTTP ' + r.status);
        return r.text();
      })
      .then(function (text) { cache[href] = text; return text; });
  }

  function prefetch() {
    var links = document.querySelectorAll('.lang-switch a');
    for (var i = 0; i < links.length; i++) {
      var a = links[i];
      if (a.getAttribute('aria-current') !== 'true') {
        load(a.href).catch(function () {});
      }
    }
  }

  function commit(html, href, push) {
    var doc = new DOMParser().parseFromString(html, 'text/html');
    if (doc.documentElement.lang) {
      document.documentElement.lang = doc.documentElement.lang;
    }
    document.title = doc.title;
    document.body.replaceWith(doc.body);
    if (push) history.pushState({ langSwap: true }, '', href);
    prefetch();
  }

  function animatedApply(html, href, push) {
    if (reduceMotion) { commit(html, href, push); return; }

    if (document.startViewTransition) {
      document.startViewTransition(function () { commit(html, href, push); });
      return;
    }

    // Fallback: fade out, swap, fade in.
    var root = document.documentElement;
    root.classList.add('lang-fading');
    window.setTimeout(function () {
      commit(html, href, push);
      requestAnimationFrame(function () {
        requestAnimationFrame(function () { root.classList.remove('lang-fading'); });
      });
    }, 160);
  }

  function swap(href, push) {
    return load(href).then(function (html) {
      animatedApply(html, href, push);
    }).catch(function () {
      location.href = href;
    });
  }

  document.addEventListener('click', function (e) {
    var target = e.target;
    var a = target && target.closest ? target.closest('.lang-switch a') : null;
    if (!a) return;
    if (e.defaultPrevented || e.button !== 0 ||
        e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    var url;
    try { url = new URL(a.getAttribute('href'), location.href); }
    catch (err) { return; }
    if (url.origin !== location.origin) return;
    e.preventDefault();
    if (a.getAttribute('aria-current') === 'true') return;
    swap(url.href, true);
  });

  window.addEventListener('popstate', function () {
    swap(location.href, false);
  });

  if (document.readyState === 'loading') {
    window.addEventListener('DOMContentLoaded', prefetch);
  } else {
    prefetch();
  }
})();
