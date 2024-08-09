
// global
var editor;
var ignore_content_change = true;

// utils
function debounce(func, timeout = 1000){
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => { func.apply(this, args); }, timeout);
  };
}

// wkwebview
function setupWKWebViewJavascriptBridge(callback) {
    if (window.WKWebViewJavascriptBridge) { return callback(WKWebViewJavascriptBridge); }
    if (window.WKWVJBCallbacks) { return window.WKWVJBCallbacks.push(callback); }
    window.WKWVJBCallbacks = [callback];
    window.webkit.messageHandlers.iOS_Native_InjectJavascript.postMessage(null)
}

// editor
require.config({
    paths: {
        vs: 'monaco-editor/min/vs'
    }
});

// init
require(['vs/editor/editor.main'], function () {
    editor = monaco.editor.create(document.getElementById('container'), {
        value: '',
        language: 'javascript',
        automaticLayout: true,
        theme: editor_theme,
    });
    
    setupWKWebViewJavascriptBridge(function(bridge) {
        
        // api provide
        bridge.registerHandler('editor_setValue', function(data, responseCallback) {
            editor.setValue(data.value);
            ignore_content_change = false;
            responseCallback({ 'result':'ok' })
        })
        bridge.registerHandler('editor_getValue', function(data, responseCallback) {
            let value = editor.getValue();
            responseCallback({
                'result': 'ok',
                'value': value
            });
        })
        bridge.registerHandler('editor_setReadonly', function(data, responseCallback) {
            let value = data.readonly;
            if (value == undefined) { value = false; }
            editor.updateOptions({ readOnly: value })
            responseCallback({
                'result': 'ok',
                'readonly': value
            });
        })
        
        
        function log(text) {
            bridge.callHandler('event_printLog', {
                value: text
            }, function(response){
            })
        }
        
        // auto save
        function save() {
            let value = editor.getValue();
            bridge.callHandler('event_editorSave', {
                value: value
            }, function(response){
                console.log(response);
            })
        }
        const debounceSave = debounce(() => save());
        editor.onDidChangeModelContent(function (e) {
            if (ignore_content_change) {
                log('content change ignored, decrease useless save')
            } else {
                log('content did change');
                log(JSON.stringify(e));
                debounceSave();
            }
        });
        
        // tell ready
        bridge.callHandler('event_editorReady',{}, function(response){})
    })
    
});
