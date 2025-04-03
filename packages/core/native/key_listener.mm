#import <napi.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

// 全局状态
struct {
    bool isListening;
    Napi::ThreadSafeFunction tsfn;
    id localMonitor;
    id globalMonitor;
    NSTimeInterval lastEventTime;
} state;

// 事件数据结构
struct KeyEventData {
    uint16_t keyCode;
};

// 安全地处理事件回调
bool SafeHandleKeyEvent(NSEvent* event) {
    @try {
        if (!state.isListening || !state.tsfn) {
            return false;
        }

        // 检查事件时间戳，防止重复事件
        NSTimeInterval currentTime = event.timestamp;
        if (currentTime - state.lastEventTime < 0.01) { // 10毫秒内的事件视为重复
            return false;
        }
        state.lastEventTime = currentTime;

        // 根据事件类型决定是否处理
        if (event.type == NSEventTypeFlagsChanged) {
            // 对于修饰键，只在 FlagsChanged 事件时处理
            KeyEventData* data = new KeyEventData();
            data->keyCode = event.keyCode;
            state.tsfn.NonBlockingCall(data, [](Napi::Env env, Napi::Function jsCallback, KeyEventData* data) {
                @autoreleasepool {
                    Napi::Object event = Napi::Object::New(env);
                    event.Set("keyCode", data->keyCode);
                    jsCallback.Call({event});
                    delete data;
                }
            });
            return true;
        } else if (event.type == NSEventTypeKeyDown) {
            // 对于普通按键，只在 KeyDown 事件时处理
            // 检查是否是修饰键的 KeyDown 事件
            NSUInteger modifierFlags = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
            bool isModifierKey = (event.keyCode >= 54 && event.keyCode <= 63); // 修饰键的键码范围
            if (!isModifierKey) {
                KeyEventData* data = new KeyEventData();
                data->keyCode = event.keyCode;
                state.tsfn.NonBlockingCall(data, [](Napi::Env env, Napi::Function jsCallback, KeyEventData* data) {
                    @autoreleasepool {
                        Napi::Object event = Napi::Object::New(env);
                        event.Set("keyCode", data->keyCode);
                        jsCallback.Call({event});
                        delete data;
                    }
                });
                return true;
            }
        }
        return false;

    } @catch (NSException* exception) {
        NSLog(@"Error handling key event: %@", exception);
        return false;
    }
}

// 启动监听器
Napi::Value Start(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    
    if (info.Length() < 1 || !info[0].IsFunction()) {
        Napi::TypeError::New(env, "Function expected as first argument").ThrowAsJavaScriptException();
        return env.Undefined();
    }
    
    if (state.isListening) {
        return Napi::Boolean::New(env, true);
    }
    
    @try {
        Napi::Function callback = info[0].As<Napi::Function>();
        
        // 创建线程安全函数引用
        state.tsfn = Napi::ThreadSafeFunction::New(
            env,
            callback,
            "KeyListener",
            0,
            1,
            []( Napi::Env ) {
                state.isListening = false;
            }
        );
        
        // 初始化状态
        state.lastEventTime = 0;
        
        // 添加本地按键监听器
        state.localMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskKeyDown | NSEventMaskFlagsChanged)
            handler:^NSEvent *(NSEvent *event) {
                SafeHandleKeyEvent(event);
                return event;
            }];
        
        // 添加全局按键监听器
        state.globalMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:(NSEventMaskKeyDown | NSEventMaskFlagsChanged)
            handler:^(NSEvent *event) {
                SafeHandleKeyEvent(event);
            }];
        
        if (!state.localMonitor || !state.globalMonitor) {
            NSLog(@"Failed to create monitors");
            if (state.localMonitor) {
                [NSEvent removeMonitor:state.localMonitor];
                state.localMonitor = nil;
            }
            if (state.globalMonitor) {
                [NSEvent removeMonitor:state.globalMonitor];
                state.globalMonitor = nil;
            }
            if (state.tsfn) {
                state.tsfn.Release();
            }
            Napi::Error::New(env, "Failed to create key monitors").ThrowAsJavaScriptException();
            return env.Undefined();
        }
        
        state.isListening = true;
        return Napi::Boolean::New(env, true);
        
    } @catch (NSException* exception) {
        NSLog(@"Error starting key listener: %@", exception);
        Napi::Error::New(env, [[exception description] UTF8String]).ThrowAsJavaScriptException();
        return env.Undefined();
    }
}

// 停止监听器
Napi::Value Stop(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    
    if (!state.isListening) {
        return Napi::Boolean::New(env, true);
    }
    
    @try {
        // 移除事件监听器
        if (state.localMonitor) {
            [NSEvent removeMonitor:state.localMonitor];
            state.localMonitor = nil;
        }
        
        if (state.globalMonitor) {
            [NSEvent removeMonitor:state.globalMonitor];
            state.globalMonitor = nil;
        }
        
        // 释放线程安全函数
        if (state.tsfn) {
            state.tsfn.Release();
        }
        
        state.isListening = false;
        return Napi::Boolean::New(env, true);
        
    } @catch (NSException* exception) {
        NSLog(@"Error stopping key listener: %@", exception);
        Napi::Error::New(env, [[exception description] UTF8String]).ThrowAsJavaScriptException();
        return env.Undefined();
    }
}

// 获取监听状态
Napi::Value IsListening(const Napi::CallbackInfo& info) {
    return Napi::Boolean::New(info.Env(), state.isListening);
}

// 初始化模块
Napi::Object Init(Napi::Env env, Napi::Object exports) {
    @try {
        state.isListening = false;
        state.localMonitor = nil;
        state.globalMonitor = nil;
        state.lastEventTime = 0;
        
        exports.Set("start", Napi::Function::New(env, Start));
        exports.Set("stop", Napi::Function::New(env, Stop));
        exports.Set("isListening", Napi::Function::New(env, IsListening));
        
        return exports;
        
    } @catch (NSException* exception) {
        NSLog(@"Error initializing module: %@", exception);
        Napi::Error::New(env, [[exception description] UTF8String]).ThrowAsJavaScriptException();
        return exports;
    }
}

NODE_API_MODULE(command_key_listener, Init) 