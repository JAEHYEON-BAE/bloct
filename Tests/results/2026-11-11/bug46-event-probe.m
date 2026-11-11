// Test-only observer: leave AppKit's behavior intact, log unhandled keys and stacks.
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <execinfo.h>
#import <stdio.h>
static IMP originalNoResponder;
static unsigned short lastCode;
static NSUInteger lastFlags;
static void probeNoResponder(id self, SEL cmd, SEL selector) {
    if (selector == @selector(keyDown:)) {
        fprintf(stderr,"ESC_PROBE unhandled keyDown lastCode=%u flags=%lu receiver=%s\n", lastCode, (unsigned long)lastFlags,object_getClassName(self));
        void *frames[20]; int count=backtrace(frames,20); backtrace_symbols_fd(frames,count,2);
    }
    ((void(*)(id,SEL,SEL))originalNoResponder)(self,cmd,selector);
}
__attribute__((constructor)) static void installProbe(void) {
    fprintf(stderr,"ESC_PROBE installed\n");
    Method method=class_getInstanceMethod([NSResponder class],@selector(noResponderFor:));
    originalNoResponder=method_setImplementation(method,(IMP)probeNoResponder);
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
            lastCode=event.keyCode;lastFlags=event.modifierFlags;
            fprintf(stderr,"ESC_PROBE keyDown code=%u flags=%lu\n",lastCode,(unsigned long)lastFlags);
            return event;
        }];
    });
}
