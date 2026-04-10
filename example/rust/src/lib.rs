use mermaid_rs_renderer::{render_with_options, RenderOptions, Theme};
use std::ffi::{CStr, CString};
use std::os::raw::c_char;

fn render_to_cstring(input: &str, options: RenderOptions) -> *mut c_char {
    match render_with_options(input, options) {
        Ok(svg) => match CString::new(svg) {
            Ok(c) => c.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        Err(_) => std::ptr::null_mut(),
    }
}

fn parse_input(input: *const c_char) -> Option<&'static str> {
    if input.is_null() {
        return None;
    }
    unsafe { CStr::from_ptr(input) }.to_str().ok()
}

/// Render with light theme (modern).
#[no_mangle]
pub extern "C" fn mermaid_render(input: *const c_char) -> *mut c_char {
    let Some(input_str) = (unsafe { parse_input_raw(input) }) else {
        return std::ptr::null_mut();
    };
    render_to_cstring(input_str, RenderOptions::modern())
}

/// Render with dark theme.
#[no_mangle]
pub extern "C" fn mermaid_render_dark(input: *const c_char) -> *mut c_char {
    let Some(input_str) = (unsafe { parse_input_raw(input) }) else {
        return std::ptr::null_mut();
    };
    let mut opts = RenderOptions::modern();
    opts.theme = dark_theme();
    render_to_cstring(input_str, opts)
}

/// Free a string returned by mermaid_render / mermaid_render_dark.
#[no_mangle]
pub extern "C" fn mermaid_free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            drop(CString::from_raw(s));
        }
    }
}

unsafe fn parse_input_raw(input: *const c_char) -> Option<&'static str> {
    if input.is_null() {
        return None;
    }
    CStr::from_ptr(input).to_str().ok()
}

fn dark_theme() -> Theme {
    let mut t = Theme::modern();
    t.background = "#1E1E2E".to_string();
    t.primary_color = "#313244".to_string();
    t.primary_text_color = "#CDD6F4".to_string();
    t.primary_border_color = "#585B70".to_string();
    t.line_color = "#7F849C".to_string();
    t.secondary_color = "#45475A".to_string();
    t.tertiary_color = "#313244".to_string();
    t.text_color = "#CDD6F4".to_string();
    t.edge_label_background = "rgba(30,30,46,0.92)".to_string();
    t.cluster_background = "#181825".to_string();
    t.cluster_border = "#585B70".to_string();
    t.sequence_actor_fill = "#313244".to_string();
    t.sequence_actor_border = "#585B70".to_string();
    t.sequence_actor_line = "#7F849C".to_string();
    t.sequence_note_fill = "#45475A".to_string();
    t.sequence_note_border = "#585B70".to_string();
    t.sequence_activation_fill = "#45475A".to_string();
    t.sequence_activation_border = "#585B70".to_string();
    t.pie_title_text_color = "#CDD6F4".to_string();
    t.pie_section_text_color = "#CDD6F4".to_string();
    t.pie_legend_text_color = "#CDD6F4".to_string();
    t.pie_stroke_color = "#585B70".to_string();
    t.pie_outer_stroke_color = "#585B70".to_string();
    t
}
