'use strict';

module.exports = function(grunt) {
  grunt.initConfig({

    pkg: grunt.file.readJSON('package.json'),

    coffeelint: {
      src: 'src/*.coffee'
    }

  });

  grunt.loadNpmTasks('grunt-coffeelint');

  grunt.registerTask('syntax', 'coffeelint');
  grunt.registerTask('test', 'syntax');
  grunt.registerTask('default', 'test');
};
