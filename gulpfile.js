var gulp = require("gulp"),
    jade = require("gulp-jade"),

    coffee = require("gulp-coffee"),
    concat = require("gulp-concat"),
    uglify = require("gulp-uglify"),
    plumber = require("gulp-plumber"),
    wrap = require("gulp-wrap"),
    rename = require("gulp-rename"),

    newer = require("gulp-newer"),
    minifyHTML = require("gulp-minify-html"),
    sass = require("gulp-ruby-sass"),
    csslint = require("gulp-csslint"),
    minifyCSS = require("gulp-minify-css"),
    imagemin = require("gulp-imagemin"),
    watch = require("gulp-watch"),
    size = require("gulp-filesize"),
    notify = require("gulp-notify"),
    connect = require("gulp-connect"),
    scsslint = require("gulp-scss-lint"),
    newer = require("gulp-newer")
    cache = require("gulp-cached");

var paths = {
    app: "app",
    dist: "dist",
    html: "app/*.html",
    jade: "app/partials/**/*.jade",
    appStyles: "app/styles/**/*.scss",
    distStyles: "dist/styles",
    sassMain: "app/styles/main.scss",
    css:  "dist/styles/**/*.css",
    images: "app/images/**/*",
    coffee: ["app/coffee/*.coffee",
             "config/main.coffee",
             "app/coffee/**/*.coffee"]
};

// Ordered list of vendor/external libraries.
var vendorJsLibs = [
    "app/vendor/jquery/dist/jquery.js",
    "app/vendor/lodash/dist/lodash.js",
    "app/vendor/emoticons/lib/emoticons.js",
    "app/vendor/underscore.string/lib/underscore.string.js",
    "app/vendor/angular/angular.js",
    "app/vendor/angular-route/angular-route.js",
    "app/vendor/angular-sanitize/angular-sanitize.js",
    "app/vendor/angular-animate/angular-animate.js"
]

////////////////////////////////////////////////////////////////////////////
// Layout/CSS Related tasks
////////////////////////////////////////////////////////////////////////////

gulp.task("jade", function() {
  return gulp.src(paths.jade)
             .pipe(plumber())
             .pipe(jade({pretty: true}))
             .pipe(gulp.dest(paths.dist + "/partials"));
});

gulp.task("template", function() {
    return gulp.src(paths.app + "/index.jade")
               .pipe(plumber())
               .pipe(jade({pretty: true, locals:{v:(new Date()).getTime()}}))
               .pipe(gulp.dest(paths.dist));
});

// Sass lint
gulp.task("scss-lint", function() {
    gulp.src([paths.appStyles, "!/**/bourbon/**/*.scss"])
        .pipe(cache("scsslint"))
        .pipe(scsslint({config: "scsslint.yml"}))
});

// Sass Files
gulp.task("sass", function () {
    return gulp.src(paths.sassMain)
               .pipe(plumber())
               .pipe(sass())
               .pipe(gulp.dest(paths.distStyles));
});

// CSS Linting and report
gulp.task("css", ["sass"], function() {
    gulp.src([paths.css, "!"+paths.dist+"/styles/vendor/**/*.css"])
        .pipe(csslint("csslintrc.json"))
        .pipe(csslint.reporter());
});


// Minify CSS
gulp.task("minifyCSS", ["css", "sass"], function () {
    gulp.src("dist/styles/main.css")
        .pipe(minifyCSS())
        .pipe(gulp.dest(paths.distStyles))
        .pipe(size());
});

gulp.task("imagemin", function () {
    return gulp.src(paths.images)
               .pipe(plumber())
               .pipe(imagemin({progressive: true}))
               .pipe(gulp.dest(paths.dist+"/images"));
});

////////////////////////////////////////////////////////////////////////////
// JS Related tasks
////////////////////////////////////////////////////////////////////////////

gulp.task("coffee", function() {
    return gulp.src(paths.coffee)
               .pipe(plumber())
               .pipe(coffee())
               .pipe(concat("app.js"))
               .pipe(gulp.dest("dist/js/"));
});

gulp.task("jslibs", function() {
    return gulp.src(vendorJsLibs)
               .pipe(plumber())
               .pipe(concat("libs.js"))
               .pipe(gulp.dest("dist/js/"));
});

gulp.task("locales", function() {
    gulp.src("app/locales/en/app.json")
        .pipe(wrap("angular.module('locales.en', []).constant('locales.en', <%= contents %>);"))
        .pipe(rename("locale.en.coffee"))
        .pipe(gulp.dest("app/coffee/"));

    gulp.src("app/locales/es/app.json")
        .pipe(wrap("angular.module('locales.es', []).constant('locales.es', <%= contents %>);"))
        .pipe(rename("locale.es.coffee"))
        .pipe(gulp.dest("app/coffee/"));
});


////////////////////////////////////////////////////////////////////////////
// Common tasks
////////////////////////////////////////////////////////////////////////////

// Copy Files
gulp.task("copy", ["sass"], function() {
    // Copy fonts
    gulp.src(paths.app+"/fonts/*")
        .pipe(gulp.dest(paths.dist+"/fonts/"));

    gulp.src(paths.app+"/images/*")
        .pipe(gulp.dest(paths.dist+"/images/"));
});

gulp.task("connect", function() {
    connect.server({
        root: paths.dist,
        livereload: true
    });
});

// Rerun the task when a file changes
gulp.task("watch", function() {
    gulp.watch(paths.jade, ["jade"]);
    gulp.watch(paths.appStyles, ["scss-lint", "sass", "css"]);
    gulp.watch(paths.coffee, ["coffee"]);
});

gulp.task("express", function() {
    var express = require("express");
    var app = express();

    app.use("/js", express.static(__dirname + "/dist/js"));
    app.use("/styles", express.static(__dirname + "/dist/styles"));
    app.use("/images", express.static(__dirname + "/dist/images"));
    app.use("/partials", express.static(__dirname + "/dist/partials"));
    app.use("/fonts", express.static(__dirname + "/dist/fonts"));

    app.all("/*", function(req, res, next) {
        // Just send the index.html for other files to support HTML5Mode
        res.sendfile("index.html", { root: __dirname + "/dist/" });
    });

    app.listen(9001);
});


// The default task (called when you run `gulp` from cli)
gulp.task("default", [
    "jade",
    "template",
    "sass",
    "css",
    "copy",
    "coffee",
    "jslibs",
    "connect",
    "express",
    "watch"
]);

// The default task (called when you run `gulp` from cli)
gulp.task("dist", [
    "jade",
    "sass",
    "css",
    "minifyCSS",
    "imagemin",
    "copy",
    "connect",
    "watch"
]);
