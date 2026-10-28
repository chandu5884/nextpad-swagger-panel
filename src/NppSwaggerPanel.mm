/*
 * Swagger Panel for Nextpad++ (macOS)
 * Renders the current Swagger / OpenAPI document (YAML or JSON) with
 * Swagger UI in a docked side panel. Live-updates as you type.
 * Swagger UI and js-yaml are bundled in <dylib_dir>/resources, so it works offline.
 */

#include "NppPluginInterfaceMac.h"
#include "Scintilla.h"

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#include <dlfcn.h>
#include <string>

// ── Plugin state ────────────────────────────────────────────────────────

static const char *PLUGIN_NAME = "Swagger Panel";
static const int NB_FUNC = 4;
static FuncItem funcItem[NB_FUNC];
NppData nppData;  // non-static: used by SendMessage macro

static ShortcutKey skToggle = { true, true, true, false, 'W' }; // Ctrl+Alt+Shift+W

static NSView *sContentView = nil;
static WKWebView *sWebView = nil;
static NSPanel *sFloatingPanel = nil;
static intptr_t sPanelHandle = 0;
static BOOL sPageLoaded = NO;
static BOOL sRenderPending = NO;
static uint64_t sRenderGeneration = 0;

static void togglePanel();
static void renderNow();

// ── Helpers ─────────────────────────────────────────────────────────────

static intptr_t npp(uint32_t msg, uintptr_t w = 0, intptr_t l = 0)
{
    return nppData._sendMessage(nppData._nppHandle, msg, w, l);
}

static NppHandle getCurScintilla()
{
    int which = -1;
    npp(NPPM_GETCURRENTSCINTILLA, 0, (intptr_t)&which);
    if (which == -1) return 0;
    return (which == 0) ? nppData._scintillaMainHandle : nppData._scintillaSecondHandle;
}

static std::string getDocumentText()
{
    NppHandle h = getCurScintilla();
    if (!h) return "";
    intptr_t len = nppData._sendMessage(h, SCI_GETLENGTH, 0, 0);
    std::string buf(len + 1, '\0');
    nppData._sendMessage(h, SCI_GETTEXT, len + 1, (intptr_t)buf.data());
    buf.resize(len);
    return buf;
}

static NSString *resourcesDir()
{
    Dl_info info;
    if (dladdr((void *)&resourcesDir, &info) && info.dli_fname) {
        NSString *dylib = [NSString stringWithUTF8String:info.dli_fname];
        return [[dylib stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"resources"];
    }
    return nil;
}

static BOOL panelIsShown()
{
    if (sFloatingPanel) return sFloatingPanel.isVisible;
    return sContentView.window != nil && sContentView.superview != nil && !sContentView.isHiddenOrHasHiddenAncestor;
}

// ── Web view ────────────────────────────────────────────────────────────

@interface SwaggerNavDelegate : NSObject <WKNavigationDelegate>
@end

@implementation SwaggerNavDelegate
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    sPageLoaded = YES;
    renderNow();
}
// Open "external docs" and similar links in the default browser.
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action
    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *url = action.request.URL;
    if (action.navigationType == WKNavigationTypeLinkActivated && ![url.scheme isEqualToString:@"file"]) {
        [[NSWorkspace sharedWorkspace] openURL:url];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}
@end

static SwaggerNavDelegate *sNavDelegate = nil;

static void ensureContentView()
{
    if (sContentView) return;
    sContentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 600, 700)];
    sContentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
    sWebView = [[WKWebView alloc] initWithFrame:sContentView.bounds configuration:cfg];
    sWebView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    sNavDelegate = [[SwaggerNavDelegate alloc] init];
    sWebView.navigationDelegate = sNavDelegate;
    [sContentView addSubview:sWebView];

    NSString *dir = resourcesDir();
    NSURL *index = [NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"index.html"]];
    [sWebView loadFileURL:index allowingReadAccessToURL:[NSURL fileURLWithPath:dir]];
}

static void ensureFloatingPanel()
{
    if (sFloatingPanel) return;
    sFloatingPanel = [[NSPanel alloc] initWithContentRect:NSMakeRect(200, 200, 700, 800)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskUtilityWindow
        backing:NSBackingStoreBuffered defer:NO];
    sFloatingPanel.title = @"Swagger Panel";
    sFloatingPanel.hidesOnDeactivate = NO;
    sFloatingPanel.releasedWhenClosed = NO;
    sContentView.frame = sFloatingPanel.contentView.bounds;
    [sFloatingPanel.contentView addSubview:sContentView];
}

// Push the current document into the page as a JSON-encoded string.
static void renderNow()
{
    sRenderPending = NO;
    if (!sWebView || !sPageLoaded || !panelIsShown()) return;
    @autoreleasepool {
        std::string text = getDocumentText();
        NSString *s = [[NSString alloc] initWithBytes:text.data() length:text.size() encoding:NSUTF8StringEncoding];
        if (!s) s = @"";
        NSData *json = [NSJSONSerialization dataWithJSONObject:@[s] options:0 error:nil];
        NSString *arr = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
        NSString *js = [NSString stringWithFormat:@"window.renderSpec(%@[0])", arr];
        [sWebView evaluateJavaScript:js completionHandler:nil];
    }
}

// Debounced render — typing shouldn't rebuild Swagger UI on every keystroke.
static void scheduleRender(int delayMs)
{
    uint64_t gen = ++sRenderGeneration;
    sRenderPending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)delayMs * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
        if (gen == sRenderGeneration) renderNow();
    });
}

// ── Commands ────────────────────────────────────────────────────────────

static void togglePanel()
{
    ensureContentView();

    if (sPanelHandle == 0 && sFloatingPanel == nil) {
        sPanelHandle = npp(NPPM_DMM_REGISTERPANEL, (uintptr_t)(__bridge void *)sContentView,
                           (intptr_t)"Swagger Panel");
        if (sPanelHandle <= 0) {
            sPanelHandle = 0;
            ensureFloatingPanel();
        }
    }

    BOOL show = !panelIsShown();
    npp(NPPM_SETMENUITEMCHECK, (uintptr_t)funcItem[0]._cmdID, show ? 1 : 0);
    if (show) {
        if (sPanelHandle > 0) npp(NPPM_DMM_SHOWPANEL, (uintptr_t)sPanelHandle, 0);
        else [sFloatingPanel orderFront:nil];
        scheduleRender(50);
    } else {
        if (sPanelHandle > 0) npp(NPPM_DMM_HIDEPANEL, (uintptr_t)sPanelHandle, 0);
        else [sFloatingPanel orderOut:nil];
    }
}

static void refreshPanel()
{
    if (!panelIsShown()) togglePanel();
    else renderNow();
}

static void showAbout()
{
    NSAlert *a = [[NSAlert alloc] init];
    a.messageText = @"Swagger Panel";
    a.informativeText = @"Shows the current Swagger 2.0 / OpenAPI 3.x file (YAML or JSON) "
                        @"as interactive Swagger UI in a side panel.\n\n"
                        @"Toggle: Ctrl+Alt+Shift+W";
    [a runModal];
}

// ── Exports ─────────────────────────────────────────────────────────────

extern "C" NPP_EXPORT void setInfo(NppData data)
{
    nppData = data;

    strlcpy(funcItem[0]._itemName, "Toggle Swagger Panel", NPP_MENU_ITEM_SIZE);
    funcItem[0]._pFunc = togglePanel;
    funcItem[0]._init2Check = false;
    funcItem[0]._pShKey = &skToggle;

    strlcpy(funcItem[1]._itemName, "Refresh", NPP_MENU_ITEM_SIZE);
    funcItem[1]._pFunc = refreshPanel;
    funcItem[1]._init2Check = false;
    funcItem[1]._pShKey = nullptr;

    strlcpy(funcItem[2]._itemName, "-", NPP_MENU_ITEM_SIZE);
    funcItem[2]._pFunc = nullptr;
    funcItem[2]._init2Check = false;
    funcItem[2]._pShKey = nullptr;

    strlcpy(funcItem[3]._itemName, "About", NPP_MENU_ITEM_SIZE);
    funcItem[3]._pFunc = showAbout;
    funcItem[3]._init2Check = false;
    funcItem[3]._pShKey = nullptr;
}

extern "C" NPP_EXPORT const char *getName()
{
    return PLUGIN_NAME;
}

extern "C" NPP_EXPORT FuncItem *getFuncsArray(int *nbF)
{
    *nbF = NB_FUNC;
    return funcItem;
}

extern "C" NPP_EXPORT void beNotified(SCNotification *notifyCode)
{
    switch (notifyCode->nmhdr.code) {
        case NPPN_BUFFERACTIVATED:
            if (sContentView) scheduleRender(50);
            break;
        case SCN_MODIFIED:
            if (sContentView && (notifyCode->modificationType & (SC_MOD_INSERTTEXT | SC_MOD_DELETETEXT)))
                scheduleRender(600);
            break;
        case NPPN_SHUTDOWN:
            if (sPanelHandle > 0) npp(NPPM_DMM_UNREGISTERPANEL, (uintptr_t)sPanelHandle, 0);
            break;
        default:
            break;
    }
}

extern "C" NPP_EXPORT intptr_t messageProc(uint32_t /*msg*/, uintptr_t /*wParam*/, intptr_t /*lParam*/)
{
    return 1;
}
