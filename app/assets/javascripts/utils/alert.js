/* eslint-disable no-multi-str */
(function () {
  var globals = this;

  function createAlertDOM(text, type, icon, customClass) {
    return '\
      <div class="alert alert-dismissible fade in text-left ' + customClass + ' alert-' + type + '" style="display: none">\
        <button class="close alert-hide" data-dismiss="alert" type="button">\
          <span aria-hidden="true">×</span>\
          <span class="sr-only">Close</span>\
        </button>\
        <div class="alert-message">\
          <div class="alert-icon pull-left">\
            <i class="fa fa-3x pull-left icon ' + icon + '"></i>\
          </div>\
          <span class="text">' + text + '</span>\
        </div>\
      </div>';
  }

  function showAlert(message, type, klass) {
    var $container = $('.alerts-container');

    var customClass = klass || '';
    var icon = type === 'alert' ? 'fa-exclamation-circle' : 'fa-info-circle';
    var typeClass = type === 'alert' ? 'danger' : 'info';

    var dom = createAlertDOM(message, typeClass, icon, customClass);
    var $alert = $(dom);

    $container.append($alert);
    $alert.fadeIn(100);

    return $alert;
  }

  globals.showAlert = showAlert;
}.call(window));
