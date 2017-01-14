var through = require('through2');
var gutil = require('gulp-util');
var yaml = require('js-yaml');
var merge = require('merge');
var twig = require('twig').twig;

var markdownIt = require('markdown-it');
var externalLinks = require('markdown-it-external-links');
var md = markdownIt({
    html: true,
    linkify: true,
    typographer: true,
    breaks: true
}).use(externalLinks, {
    externalTarget: '_blank'
});

var PluginError = gutil.PluginError;

module.exports = function (opt) {

    function markownValues(doc) {
        for (var key in doc) {
            if (doc.hasOwnProperty(key)) {
                if (typeof doc[key] == 'string') {
                    doc[key] = md.renderInline(doc[key]);
                } else if (typeof doc[key] == 'object') {
                    markownValues(doc[key]);
                }
            }
        }
    }

    function transform(file, enc, cb) {

        if (file.isNull()) return cb(null, file);
        if (file.isStream()) return cb(new PluginError('gulp-ladb-i18n-compile', 'Streaming not supported'));

        var data;
        try {

            var contents = file.contents.toString('utf8');
            var ymlDocument = yaml.safeLoad(contents);

            markownValues(ymlDocument);

            var filename = file.path.substr(file.base.length);
            var language = filename.substr(0, filename.length - '.yml'.length);

            var resources = {};
            resources[language] = {
                translation: ymlDocument
            };
            var i18nextOptions = {
                lng: language,
                resources: resources
            };

            data = 'i18next.init(' + JSON.stringify(i18nextOptions) + ');';

        } catch (err) {
            return cb(new PluginError('gulp-ladb-i18n-compile', err));
        }

        file.contents = new Buffer(data);
        file.path = file.base + language + '.js';

        cb(null, file);
    }

    return through.obj(transform);
};