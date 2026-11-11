#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <execinfo.h>
#import <stdio.h>
static void probeBeep(void) {
    fprintf(stderr, "ESC_PROBE NSBeep\n");
    void *frames[24]; int count=backtrace(frames,24); backtrace_symbols_fd(frames,count,2);
    NSBeep();
}
__attribute__((used)) static struct { const void *replacement; const void *original; } interpose[]
__attribute__((section("__DATA,__interpose"))) = {{(const void *)probeBeep,(const void *)NSBeep}};
static IMP originalNoResponder;
static void probeNoResponder(id self, SEL cmd, SEL selector) {
    fprintf(stderr,"ESC_PROBE noResponderFor:%s receiver=%s\n",sel_getName(selector),object_getClassName(self));
    ((void(*)(id,SEL,SEL))originalNoResponder)(self,cmd,selector);
}
__attribute__((constructor)) static void installProbe(void) {
    fprintf(stderr,"ESC_PROBE installed\n");
    Method method=class_getInstanceMethod([NSResponder class],@selector(noResponderFor:));
    originalNoResponder=method_setImplementation(method,(IMP)probeNoResponder);
}
