(function() {

    // Make sure we only load the script once.
    if (window.OC && window.OC.widgets) {
        window.OC.widgets['sponsorWidget'] = window.OC.widgets['sponsorWidget'] || [];
        return;
    }

    window.OC = window.OC || {};
    window.OC.widgets = { 'sponsorWidget': [] };
    window.addEventListener('message', function (e) {
        // if (e.origin !== 'https://opencollective.com') return;
        if (typeof e.data !== 'string' || e.data.substr(0, 3) !== 'oc-') return;
        var data = JSON.parse(e.data.substr(3));
        var widget = data.id.substr(0, data.id.indexOf('-'));
        for (var i = 0; i < window.OC.widgets[widget].length; i++) {
            if (window.OC.widgets[widget][i].id === data.id) {
                window.OC.widgets[widget][i].iframe.height = data.height + 10;
                window.OC.widgets[widget][i].loading.style.display = 'none';
                return;
            }
        }
    });

    function css(selector, property) {
        var element = document.querySelector(selector);
        if (!element) return null;
        return window.getComputedStyle(element, null).getPropertyValue(property);
    }

    var style =
        '{}' ||
        JSON.stringify({
            body: {
                fontFamily: css('body', 'font-family')
            },
            h2: {
                fontFamily: css('h2', 'font-family'),
                fontSize: css('h2', 'font-size'),
                color: css('h2', 'color')
            },
            a: {
                fontFamily: css('a', 'font-family'),
                fontSize: css('a', 'font-size'),
                color: css('a', 'color')
            }
        });

    function OpenCollectiveWidget(widget, collectiveSlug, anchor) {
        this.anchor = anchor;
        this.styles = window.getComputedStyle(anchor.parentNode, null);
        this.id = widget + '-iframe-' + Math.floor(Math.random() * 10000);

        this.getAttributes = function() {
            var attributes = {};
            [].slice.call(this.anchor.attributes).forEach(function(attr) {
                attributes[attr.name] = attr.value;
            });
            return attributes;
        };

        this.inject = function(e) {
            this.anchor.parentNode.insertBefore(e, this.anchor);
        };

        var attributes = this.getAttributes();
        var limit = attributes.limit || 10;
        var width = attributes.width || '100%';
        var height = attributes.height || 0;
        this.loading = document.createElement('div');
        this.loading.className = 'oc-loading-container';
        this.logo = document.createElement('img');
        this.logo.className = 'oc-loading';
        this.logo.src = 'https://opencollective.com/static/images/opencollective-icon.svg';
        this.loading.appendChild(this.logo);
        this.iframe = document.createElement('iframe');
        this.iframe.id = this.id;
        this.iframe.src = 'http://localhost:3000/?id=' + this.id;
        this.iframe.width = width;
        this.iframe.height = height;
        this.iframe.frameBorder = 0;
        this.iframe.scrolling = 'no';

        this.el = document.createElement('div');
        this.el.className = 'opencollective-' + widget;
        this.el.appendChild(this.loading);
        this.el.appendChild(this.iframe);

        this.inject(this.el);
    }

    var initStylesheet = function() {
        var style = document.createElement('style');
        // WebKit hack :(
        style.appendChild(document.createTextNode(''));
        // Add the <style> element to the page
        document.head.appendChild(style);
        style.sheet.insertRule('.oc-loading-container { display: flex; justify-content: center; text-align: center; }');
        style.sheet.insertRule('.oc-loading { animation: oc-rotate 0.8s infinite linear; }');
        style.sheet.insertRule('@keyframes oc-rotate { 0%    { transform: rotate(0deg); } 100%  { transform: rotate(360deg); } }');
    };

    var init = function () {
        initStylesheet();
        var scriptsNodesArray = [].slice.call(document.querySelectorAll('script'));
        var regex = new RegExp('http://localhost:3000/sponsorWidget.js', 'i');
        scriptsNodesArray.map(function (s) {
            if (s.parentNode && s.parentNode.tagName === 'HEAD') {
                return;
            }
            var src = s.getAttribute('src');
            Object.keys(window.OC.widgets).forEach(function (widget) {
                if (src && src.match(regex) && src.match(new RegExp(widget + '.js'))) {
                    return window.OC.widgets[widget].push(new OpenCollectiveWidget('sponsorWidget', 'webpack', s));
                }
            });
        });
    };

    if (document.readyState !== 'loading') {
        init();
    } else {
        document.addEventListener('DOMContentLoaded', init);
    }

})();