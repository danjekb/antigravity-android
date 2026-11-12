#!/usr/bin/env python3
"""
web/patch_main.py - Dynamic patcher for web/main.js.

Locates the Appearance settings block and injects the Desktop Mode toggle
if not already present. Safe, idempotent, and resilient to upstream changes.
"""

import sys
import os
import re

def patch_main(file_path):
    if not os.path.isfile(file_path):
        print(f"[web-patch] file not found: {file_path}", file=sys.stderr)
        return False

    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    if "Desktop Mode" in content or "ag_desktop_mode" in content:
        print("[web-patch] Desktop Mode toggle already present in main.js")
    else:
        # 1. State hook injection pattern in Appearance component:
        hook_pattern = re.compile(r'(var\s+[A-Za-z0-9_$]+=[A-Za-z0-9_$]+!==3,\s*[A-Za-z0-9_$]+=[A-Za-z0-9_$]+!==2,\s*[A-Za-z0-9_$]+=[A-Za-z0-9_$]+=>\s*[A-Za-z0-9_$]+=>\{.*?\};)')
        hook_match = hook_pattern.search(content)

        # 2. JSX Theme element injection: find Theme element in Appearance
        theme_idx = content.find('{label:"Theme"')
        theme_match = None
        react_id = "A"
        if theme_idx != -1:
            window_start = max(0, theme_idx - 100)
            window_end = min(len(content), theme_idx + 500)
            window_text = content[window_start:window_end]
            theme_pattern = re.compile(
                r'([A-Za-z0-9_$]+)\.createElement\(([A-Za-z0-9_$]+),\{label:"Theme",.*?onSelect:[A-Za-z0-9_$]+\}\)'
            )
            theme_match = theme_pattern.search(window_text)
            if theme_match:
                react_id = theme_match.group(1)

        if not hook_match or not theme_match:
            print(f"[web-patch] patterns not matched: hook={bool(hook_match)}, theme={bool(theme_match)}", file=sys.stderr)
        else:
            orig_hook = hook_match.group(1)
            injected_hook = (
                f"var [isDesktop,setIsDesktop]=(0,{react_id}.useState)(()=>{{"
                "try{if(window.Android&&typeof window.Android.isDesktopMode==='function')return window.Android.isDesktopMode();"
                "var s=localStorage.getItem('ag_desktop_mode');return s===null?!1:s==='true'}catch(_){return !1}});"
                f"var onDesktopToggle=(0,{react_id}.useCallback)(v=>{{"
                "setIsDesktop(v);try{localStorage.setItem('ag_desktop_mode',String(v));"
                "if(window.Android&&typeof window.Android.setDesktopMode==='function')window.Android.setDesktopMode(v)}catch(_){}},[]);"
                + orig_hook
            )

            item_comp = "v3"
            switch_comp = "dX"
            re_idx = content.find('rightElement:')
            if re_idx != -1:
                re_window = content[max(0, re_idx - 150):min(len(content), re_idx + 150)]
                item_m = re.search(r'([A-Za-z0-9_$]+)\.createElement\(([A-Za-z0-9_$]+),\{label:[^,]+,description:[^,]+,rightElement:', re_window)
                if item_m:
                    item_comp = item_m.group(2)
                sw_m = re.search(r'rightElement:[A-Za-z0-9_$]+\.createElement\(([A-Za-z0-9_$]+),\{checked:', re_window)
                if sw_m:
                    switch_comp = sw_m.group(1)

            orig_theme = theme_match.group(0)
            injected_theme = (
                orig_theme
                + f',{react_id}.createElement({item_comp},{{label:"Desktop Mode",description:"Use desktop viewport and user agent for the workspace",'
                + f'rightElement:{react_id}.createElement({switch_comp},{{checked:isDesktop,onCheckedChange:onDesktopToggle}})}})'
            )

            content = content.replace(orig_hook, injected_hook, 1)
            content = content.replace(orig_theme, injected_theme, 1)

    # 2. Expose window.__agySettings in QC.Provider for Security Shield & Tools
    settings_target = 'customFlags:w},A.createElement(QC.Provider,{value:l}'
    settings_repl = 'customFlags:w},A.createElement(QC.Provider,{value:(window.__agySettings={store:l,I:I,Ui:Ui,gEa:gEa,iEa:iEa,hEa:hEa,qq:qq,Mt:Mt},l)}'
    if settings_target in content and "__agySettings" not in content:
        content = content.replace(settings_target, settings_repl, 1)
        print("[web-patch] Exposed window.__agySettings in QC.Provider")

    # 3. Inject Tools screen into Settings
    tools_switch_target = 'case "Regroup Google3 Chats":return A.createElement(BLb,null);case "Provide Feedback":return A.createElement(H_,null);'
    tools_switch_repl = 'case "Regroup Google3 Chats":return A.createElement(BLb,null);case "Tools":return A.createElement("div",{key:"tools",className:"agy-tools-host",ref:x=>{x&&window.__agyToolsMount&&window.__agyToolsMount(x)}});case "Provide Feedback":return A.createElement(H_,null);'
    if tools_switch_target in content and 'case "Tools":' not in content:
        content = content.replace(tools_switch_target, tools_switch_repl, 1)
        print("[web-patch] Injected Tools screen renderer into fNb")

    # Mobile settings menu list
    tools_mob_target = 'b=[...e.filter(q=>q!=="Account"),...f,...(c?[]:["Shortcuts"]),...(b.hideProvideFeedback?[]:["Provide Feedback"])];'
    tools_mob_repl = 'b=[...e.filter(q=>q!=="Account"),...f,"Tools",...(c?[]:["Shortcuts"]),...(b.hideProvideFeedback?[]:["Provide Feedback"])];'
    if tools_mob_target in content:
        content = content.replace(tools_mob_target, tools_mob_repl, 1)
        print("[web-patch] Added Tools to mobile Settings menu")

    # Desktop settings sidebar
    tools_desk_target = '"Settings")),A.createElement("div",{className:"flex flex-col gap-0.5"},k.map(F=>A.createElement(Q3,{key:F,text:F,label:Geb(F'
    tools_desk_repl = '"Settings")),A.createElement("div",{className:"flex flex-col gap-0.5"},[...k,"Tools"].map(F=>A.createElement(Q3,{key:F,text:F,label:Geb(F'
    if tools_desk_target in content:
        content = content.replace(tools_desk_target, tools_desk_repl, 1)
        print("[web-patch] Added Tools to desktop Settings sidebar")

    # Desktop tab view display
    tools_tab_target = 'A.createElement("div",{style:{display:b==="Notifications"?"block":"none"}},A.createElement(HLb,null))'
    tools_tab_repl = 'A.createElement("div",{style:{display:b==="Tools"?"block":"none"}},fNb("Tools")),A.createElement("div",{style:{display:b==="Notifications"?"block":"none"}},A.createElement(HLb,null))'
    if tools_tab_target in content and 'b==="Tools"' not in content:
        content = content.replace(tools_tab_target, tools_tab_repl, 1)
        print("[web-patch] Added Tools tab container to desktop Settings view")

    # 4. Background Resume Trajectory Stream Sync (vKa)
    vka_target = 'this._factory=a}'
    vka_repl = (
        'this._factory=a;'
        'this.refreshTrajectories=()=>{try{if(!this._factory)return;'
        'for(let [c,e]of this.JSC$7869__states.entries()){let f=e;f.link.dispose();f.underlyingProvider.dispose();f.underlyingProvider=this._factory(c);f.link=Hja(f.underlyingProvider,f.provider,{omitInitial:!0});}'
        '}catch(err){console.warn("[AGY ResumeSync] refreshTrajectories err",err)}};'
        'window.__agTrajectoriesRegistry=this;'
        'window.__agRefreshTrajectories=s=>{console.log("[AGY ResumeSync] Refreshing active trajectories triggered by",s);this.refreshTrajectories()}}'
    )
    if vka_target in content and "agTrajectoriesRegistry" not in content:
        content = content.replace(vka_target, vka_repl, 1)
        print("[web-patch] Exposed window.__agTrajectoriesRegistry & __agRefreshTrajectories in vKa")

    vka_disp_target = 'dispose(){for(let [a]of this.JSC$7869__states.entries())this._disposeEntry(a)}'
    vka_disp_repl = 'dispose(){if(window.__agTrajectoriesRegistry===this){window.__agTrajectoriesRegistry=void 0;window.__agRefreshTrajectories=void 0}for(let [a]of this.JSC$7869__states.entries())this._disposeEntry(a)}'
    if vka_disp_target in content:
        content = content.replace(vka_disp_target, vka_disp_repl, 1)
        print("[web-patch] Cleaned up global registry on vKa dispose")

    # 5. Unlock Custom Models UI (bypass isGoogleInternal & internal gates)
    cm_target1 = 'r=k.osName==="linux"&&k.isGoogleInternal;\nk=k.isGoogleInternal;'
    cm_repl1 = 'r=!0;\nk=!0;'
    if cm_target1 in content:
        content = content.replace(cm_target1, cm_repl1, 1)
        print("[web-patch] Unlocked custom models in Ycc (bypassed isGoogleInternal)")

    cm_target2 = 'var m=Pj(l),n=!!l,q=(0,A.useMemo)'
    cm_repl2 = 'var m=Pj(l),n=!0,q=(0,A.useMemo)'
    if cm_target2 in content:
        content = content.replace(cm_target2, cm_repl2, 1)
        print("[web-patch] Unlocked supportsCustomModels in cCb")

    cm_target3 = '{isGoogleInternal:O}=jS().product;'
    cm_repl3 = '{isGoogleInternal:O}=jS().product;O=!0;'
    if cm_target3 in content:
        content = content.replace(cm_target3, cm_repl3, 1)
        print("[web-patch] Unlocked showCustomModelHeader in cYb")

    cm_target4 = 'fa.customModelsFeature=N.features.customModelsFeature;'
    cm_repl4 = 'fa.customModelsFeature=N.features.customModelsFeature||{customModelsProvider:x.customModelsProvider};'
    if cm_target4 in content:
        content = content.replace(cm_target4, cm_repl4, 1)
        print("[web-patch] Injected fallback customModelsProvider into featureManager")

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

    print("[web-patch] Successfully patched main.js")
    return True

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "main.js")
    if not patch_main(path):
        sys.exit(1)
