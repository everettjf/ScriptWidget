import { useCodeMirror, EditorState, EditorView } from '@uiw/react-codemirror';
import { javascript } from '@codemirror/lang-javascript';
import { oneDark } from './darkTheme';
import React, { useState, useEffect, useRef } from 'react';
import './App.css';
import prettier from "prettier/standalone";
import parserBabel from "prettier/parser-babel";
import { myCompletions } from './autoCompletion';
import { autocompletion } from "@codemirror/autocomplete"

export default function App() {
  const [count, setCount] = useState(0);
  const editor = useRef();
  const [readonly, setReadonly] = useState(false);


  const isDarkTheme = () => {
    let info = document.getElementsByTagName("META")[1].content;
    return info.includes("theme:dark") === true;
  }

  const getExtensions = () => {
    let items = [
      javascript({ jsx: true }),
      // autocompletion({ override: [myCompletions] }),
      EditorView.updateListener.of((v) => {
        if (v.docChanged) {
          console.log("content changed");
        }
      }),
      EditorState.readOnly.of(readonly)
    ];

    if (isDarkTheme()) {
      console.log('is dark')
      items.push(oneDark);
    }

    return items;
  }
  const { setContainer, view } = useCodeMirror({
    container: editor.current,
    extensions: getExtensions(),
    value: '',
  });

  const setContent = (text) => {
    let transaction = view.state.update({ changes: { from: 0, to: view.state.doc.length, insert: text } });
    view.dispatch(transaction);
  };

  const insertContent = (text) => {
    let start = view.state.selection.main.from;
    view.dispatch(view.state.update({ changes: { from: start, insert: text } }));
    view.dispatch(view.state.update({ selection: { anchor: start + 1 } }));
  };

  const getContent = () => {
    return view.state.doc.toString();
  }

  const formatCode = () => {
    let code = getContent()
    let formatted = prettier.format(code, {
      parser: "babel",
      plugins: [
        parserBabel
      ]
    });
    setContent(formatted);
  }

  // wkwebview
  const isBridgeValid = () => {
    if (window.webkit) return true;
    return false;
  }
  const setupWKWebViewJavascriptBridge = (callback) => {
    if (window.WKWebViewJavascriptBridge) {
      // eslint-disable-next-line no-undef
      return callback(WKWebViewJavascriptBridge);
    }
    if (window.WKWVJBCallbacks) {
      return window.WKWVJBCallbacks.push(callback);
    }
    if (window.webkit) {
      window.WKWVJBCallbacks = [callback];
      window.webkit.messageHandlers.iOS_Native_InjectJavascript.postMessage(null)
    }
    console.log('Can not create valid bridge')
  }

  const initialize = () => {
    console.log('initialize');

    setupWKWebViewJavascriptBridge(function (bridge) {

      function log(text) {
        console.log(text);

        bridge.callHandler('event_printLog', {
          value: text
        }, function (response) {
          console.log(`log resopnse : ${response}`)
        })
      }

      // api provide
      bridge.registerHandler('editor_setValue', function (data, responseCallback) {
        log(`editor set value event received : ${data.value}`);
        setContent(data.value);
        responseCallback({ result: 'ok' })
      })
      bridge.registerHandler('editor_insertValue', function (data, responseCallback) {
        log(`editor insert value event received : ${data.value}`);
        if (readonly) {
          responseCallback({ result: 'failed', message: 'readonly' })
          return;
        }
        insertContent(data.value);
        responseCallback({ result: 'ok' })
      })
      bridge.registerHandler('editor_getValue', function (data, responseCallback) {
        let value = getContent();
        responseCallback({
          result: 'ok',
          'value': value
        });
      })
      bridge.registerHandler('editor_setReadonly', function (data, responseCallback) {
        let value = data.readonly;
        if (value === undefined) { value = false; }
        setReadonly(value)
        responseCallback({
          result: 'ok',
          'readonly': value
        });
      })
      bridge.registerHandler('editor_formatCode', function (data, responseCallback) {
        formatCode()
        responseCallback({
          result: 'ok',
        });
      })

      // tell ready
      bridge.callHandler('event_editorReady', {}, function (response) { })
    })
  }

  useEffect(() => {
    if (editor.current) {
      setContainer(editor.current);

      initialize();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [setContainer, setContent]);



  if (isBridgeValid()) {
    return <div className='editor' ref={editor} />
  } else {
    return <div className='app'>
      <p>You clicked {count} times</p>
      <button onClick={() => setCount(count + 1)}> Click me </button>
      <button onClick={() => setContent(`count = ${count}`)}> Set Content </button>
      <button onClick={() => setReadonly(true)}> Set Readonly </button>
      <button onClick={() => insertContent('</')}> insert content </button>
      <button onClick={() => formatCode()}> format </button>
      <div className='editor' ref={editor} />
    </div>
  }
}
