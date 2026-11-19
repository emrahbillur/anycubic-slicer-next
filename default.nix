{ lib
, stdenv
, cmake
, ninja
, git
, pkg-config
, makeWrapper
, wrapGAppsHook3
, gettext
, src
, openPluginsSrc
, libnoiseSrc
, boost
, tbb
, openssl
, curl
, freetype
, zlib
, libpng
, libjpeg
, expat
, mesa
, gtk3
, libsecret
, gst_all_1
, glew
, glfw
, cereal
, nlopt
, openvdb
, imath
, cgal
, mpfr
, opencv
, opencascade-occt
, dbus
, wxwidgets_3_3
, wxwidgetsSrc
, systemdLibs
, libX11
, webkitgtk_4_1
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "anycubic-slicer-next";
  version = "unstable-2026-10-30";

  patches = [
    ./boost-191-compat.patch
    ./boost-process-v1.patch
  ];

  nativeBuildInputs = [
    cmake
    ninja
    git
    pkg-config
    makeWrapper
    wrapGAppsHook3
    gettext
  ];

  buildInputs = [
    boost
    tbb
    openssl
    curl
    freetype
    zlib
    libpng
    libjpeg
    expat
    mesa
    gtk3
    libsecret
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    glew
    glfw
    cereal
    nlopt
    openvdb
    imath
    cgal
    mpfr
    opencv
    opencascade-occt
    dbus
    wxwidgets_3_3
    systemdLibs
    libX11
    webkitgtk_4_1.dev
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DSLIC3R_STATIC=0"
    "-DSLIC3R_GUI=1"
    "-DSLIC3R_GTK=3"
    "-DSLIC3R_PCH=OFF"
    "-DImath_DIR=${imath}/lib/cmake/Imath"
    "-DCMAKE_CXX_FLAGS=-I${opencv}/include/opencv4 -I${wxwidgetsSrc}/include -Wno-error=return-type -Wno-error=maybe-uninitialized"
  ];

  preBuild = ''
    sed -i "s/+UNKNOWN/_$(date '+%F')/" version.inc || true
  '';

  postPatch = ''
    cp -r ${openPluginsSrc} open-plugins
    chmod -R u+w open-plugins

    # The upstream Anycubic plugin manager currently reports HasPlugin() as
    # false and StartDownloadPlugins() is a TODO stub. Hide its home-page
    # install banner in this package so users are not sent to a dead action.
    printf '\n/* Plugin installation is not implemented by upstream yet. */\n#NoPluginTip { display: none !important; }\n' \
      >> resources/web/homepage/css/home.css

    mkdir -p open-plugins/WebView/include/webview
    ln -s ../webview.h open-plugins/WebView/include/webview/webview.h
    ln -s ../webviewarchivehandler.h open-plugins/WebView/include/webview/webviewarchivehandler.h
    ln -s ../webviewfshandler.h open-plugins/WebView/include/webview/webviewfshandler.h
    sed -i '1i#include <algorithm>' open-plugins/3rdparty/iguana/reflection.hpp

    # wxWidgets 3.3.4 is available, but nixpkgs does not ship its CMake config.
    substituteInPlace open-plugins/CMakeLists.txt \
      --replace-fail 'find_package(wxWidgets 3.3 CONFIG COMPONENTS' \
                     'find_package(wxWidgets 3.3 COMPONENTS'
    substituteInPlace \
      open-plugins/plugins_manager/CMakeLists.txt \
      open-plugins/plugins_sdk/communication/communication.cmake \
      open-plugins/plugins_sdk/webview/webview.cmake \
      open-plugins/plugins_sdk/event/event.cmake \
      --replace-fail 'find_package(wxWidgets 3.3 REQUIRED CONFIG COMPONENTS' \
                     'find_package(wxWidgets 3.3 REQUIRED COMPONENTS'
    substituteInPlace open-plugins/WebView/CMakeLists.txt \
      --replace-fail 'find_package(wxWidgets 3.3 CONFIG REQUIRED COMPONENTS' \
                     'find_package(wxWidgets 3.3 REQUIRED COMPONENTS'
    substituteInPlace open-plugins/utility/CMakeLists.txt \
      --replace-fail 'find_package(wxWidgets CONFIG COMPONENTS' \
                     'find_package(wxWidgets COMPONENTS'
    open_plugins_cmake_dollar='$'
    substituteInPlace open-plugins/utility/CMakeLists.txt \
      --replace-fail 'wx::core' "''${open_plugins_cmake_dollar}{wxWidgets_LIBRARIES}"
    substituteInPlace open-plugins/plugins_manager/detail/plugins_manager_impl.cpp \
      --replace-fail 'wxString::FromUTF8(xrcName)' 'xrcName'

    substituteInPlace open-plugins/cmake/subdir.cmake \
      --replace-fail 'CMAKE_SOURCE_DIR' 'CMAKE_CURRENT_SOURCE_DIR'
    substituteInPlace open-plugins/3rdparty/CMakeLists.txt \
      --replace-fail 'add_subdirectory(nlohmann)' '# Use nlohmann_json from the slicer.'
    substituteInPlace open-plugins/resources/CMakeLists.txt \
      --replace-fail 'CMAKE_SOURCE_DIR}/cmake/' 'CMAKE_CURRENT_SOURCE_DIR}/../cmake/' \
      --replace-fail 'CMAKE_PROJECT_NAME' 'PROJECT_NAME'

    # Use the local Boost module workaround for Boost 1.91 components.
    substituteInPlace \
      open-plugins/easy_log/CMakeLists.txt \
      open-plugins/plugins_base/CMakeLists.txt \
      open-plugins/plugins_sdk/event/event.cmake \
      open-plugins/utility/CMakeLists.txt \
      --replace-fail 'find_package(Boost CONFIG REQUIRED' \
                     'find_package(Boost MODULE REQUIRED'
    substituteInPlace src/slic3r/Anycubic/Anycubic.cmake \
      --replace-fail 'find_package(OpenPlugins CONFIG REQUIRED COMPONENTS ACWebView plugins_manager plugins_base easy_log utility event_sdk constant)' \
                     '# OpenPlugins targets are added directly by the parent CMake project.' \
      --replace-fail 'find_package(Boost REQUIRED CONFIG COMPONENTS json)' \
                     'find_package(Boost REQUIRED MODULE COMPONENTS json)'
    substituteInPlace src/slic3r/Anycubic/plugins/downloader/downloader.cmake \
      --replace-fail 'find_package(OpenPlugins CONFIG REQUIRED COMPONENTS constant plugins_manager plugins_base easy_log utility)' \
                     '# OpenPlugins targets are added directly by the parent CMake project.' \
      --replace-fail 'find_package(Boost REQUIRED CONFIG)' \
                     'find_package(Boost REQUIRED MODULE)'
    substituteInPlace src/slic3r/Anycubic/Anycubic.cmake \
      --replace-fail 'set(wxWidgets_LIBRARIES_NAME "wx_baseu_xml-3.1")' \
                     'set(wxWidgets_LIBRARIES_NAME "")'

    # The upstream gettext target is not part of the default build, so create
    # the catalogs explicitly before CMake installs the resources tree.
    for po_file in localization/i18n/*/OrcaSlicer*.po; do
      locale="''${po_file%/*}"
      locale="''${locale##*/}"
      mkdir -p "resources/i18n/$locale"
      msgfmt --check-format -o "resources/i18n/$locale/OrcaSlicer.mo" "$po_file"
    done

    # Utils.hpp declares std::filesystem::path but does not include its header.
    sed -i '1i#include <filesystem>' src/libslic3r/Utils.hpp
    # Boost 1.91 keeps the index loader on boost::filesystem::path while this
    # code enumerates entries with std::filesystem.
    substituteInPlace src/slic3r/Config/Version.cpp \
      --replace-fail 'idx.load(dir_entry.path());' \
                     'idx.load(boost::filesystem::path(dir_entry.path().string()));'
    substituteInPlace src/slic3r/GUI/MediaPlayCtrl.cpp \
      --replace-fail 'boost::process::pipe intermediate;' \
                     'boost::process::v1::pipe intermediate;' \
      --replace-fail 'boost::process::start_dir(' \
                     'boost::process::v1::start_dir(' \
      --replace-fail 'boost::process::std_out' \
                     'boost::process::v1::std_out' \
      --replace-fail 'boost::process::std_in' \
                     'boost::process::v1::std_in' \
      --replace-fail 'boost::process::limit_handles' \
                     'boost::process::v1::limit_handles'
    sed -i '18i#include <boost/process/v1/start_dir.hpp>\n#include <boost/process/v1/handles.hpp>' \
      src/slic3r/GUI/MediaPlayCtrl.cpp
    substituteInPlace src/slic3r/GUI/RemovableDriveManager.cpp \
      --replace-fail 'boost::process::search_path(' \
                     'boost::process::v1::search_path(' \
      --replace-fail 'boost::process::std_out' \
                     'boost::process::v1::std_out' \
      --replace-fail 'boost::process::std_err' \
                     'boost::process::v1::std_err'
    sed -i '28i#include <boost/process/v1/search_path.hpp>' \
      src/slic3r/GUI/RemovableDriveManager.cpp
    substituteInPlace src/slic3r/Utils/Bonjour.cpp \
      --replace-fail 'boost::asio::io_service' 'boost::asio::io_context' \
      --replace-fail 'asio::deadline_timer' 'asio::steady_timer' \
      --replace-fail 'io_service->post(' 'boost::asio::post(*io_service, ' \
      --replace-fail 'timer.expires_from_now(boost::posix_time::seconds(timeout));' \
                     'timer.expires_after(std::chrono::seconds(timeout));'
    substituteInPlace src/slic3r/Utils/Serial.hpp src/slic3r/Utils/Serial.cpp \
      --replace-quiet 'boost::asio::io_service' 'boost::asio::io_context' \
      --replace-quiet 'asio::io_service' 'asio::io_context'
    substituteInPlace src/slic3r/Utils/TCPConsole.cpp \
      --replace-fail 'endpoints->endpoint()' 'endpoints.begin()->endpoint()'
    substituteInPlace src/slic3r/GUI/Widgets/StateColor.cpp \
      --replace-fail 'wxASSERT(iter != gDarkColors.end());' \
                     '// Unmapped colors use the original-color fallback below.' \
      --replace-fail 'wxASSERT(iter != gLightColors.end());' \
                     '// Unmapped colors use the original-color fallback below.'
    sed -i '1i#include <wx/scopedptr.h>' src/slic3r/GUI/BitmapCache.cpp
    substituteInPlace src/slic3r/GUI/AuxiliaryDataViewModel.cpp \
      --replace-fail 'dir_path += "\\" + sel->name;' \
                     'dir_path += wxString("\\") + wxString(sel->name);' \
      --replace-fail 'dir_path += "\\" + src_bfs_path.filename().generic_wstring();' \
                     'dir_path += wxString("\\") + wxString(src_bfs_path.filename().generic_wstring());'
    substituteInPlace src/slic3r/GUI/AboutDialog.cpp \
      --replace-fail 'find_txt += std::string("\n") + text_list[i][o];' \
                     'find_txt += "\n"; find_txt += text_list[i][o];'
    substituteInPlace src/slic3r/GUI/Auxiliary.cpp \
      --replace-fail 'wxString new_fullname_path = dir.wstring() + "/" + new_fullname;' \
                     'fs::path new_dir_path = dir / fs::path(new_fullname.ToStdWstring());' \
      --replace-fail 'fs::path new_dir_path(new_fullname_path.ToStdWstring());' \
                     '// The path is assembled with filesystem path operations above.' \
      --replace-fail 'dir_path += "/" + src_bfs_path.filename().generic_wstring();' \
                     'dir_path += wxString("/") + wxString(src_bfs_path.filename().generic_wstring());' \
      --replace-fail 'dir_path += "/" + before_name + "_" + time_text + src_bfs_path.extension().wstring();' \
                     'dir_path += from_u8("/" + before_name + "_" + time_text + src_bfs_path.extension().string());'
    substituteInPlace src/slic3r/GUI/GUI.cpp \
      --replace-fail 'wxDynamicCast(comboCtrl->GetPopupControl(), wxCheckListBoxComboPopup)' \
                     'dynamic_cast<wxCheckListBoxComboPopup*>(comboCtrl->GetPopupControl())'
    substituteInPlace src/slic3r/GUI/GUI_ObjectTable.cpp \
      --replace-fail 'wxGridCellChoiceEditor::OnComboCloseUp(evt);' 'evt.Skip();'
    substituteInPlace src/slic3r/GUI/Widgets/Button.cpp \
      --replace-fail 'state_handler.attach({&text_color});' \
                     'state_handler.attach(std::vector<StateColor const *>{&text_color});'
    substituteInPlace src/slic3r/GUI/Preferences.cpp \
      --replace-fail 'e.GetString().mb_str() != app_config->get(param)' \
                     'e.GetString().ToUTF8().data() != app_config->get(param)'
    substituteInPlace src/slic3r/GUI/Search.cpp \
      --replace-fail 'return marker_by_type(opt.type, printer_technology) + opt.category_local + sep + opt.group_local + sep + opt.label_local;' \
                     'return static_cast<wchar_t>(marker_by_type(opt.type, printer_technology)) + opt.category_local + sep + opt.group_local + sep + opt.label_local;'
    substituteInPlace src/slic3r/GUI/Plater.cpp \
      --replace-fail 'wxArrayString(1, target_path.string())' \
                     'wxArrayString(1, from_u8(target_path.string()))'
    substituteInPlace src/slic3r/GUI/SendMultiMachinePage.cpp \
      --replace-quiet 'AmsRadioSelectorList::Node*' 'AmsRadioSelectorList::compatibility_iterator'
    substituteInPlace \
      src/slic3r/GUI/MultiMachinePage.cpp \
      src/slic3r/GUI/MultiMachineManagerPage.cpp \
      src/slic3r/GUI/MultiTaskManagerPage.cpp \
      src/slic3r/GUI/SendMultiMachinePage.cpp \
      src/slic3r/GUI/CalibrationPanel.cpp \
      src/slic3r/GUI/Monitor.cpp \
      src/slic3r/GUI/SelectMachinePop.cpp \
      src/slic3r/GUI/Widgets/AMSItem.cpp \
      --replace-quiet 'wxTimerEvent()' 'wxTimerEvent(*m_refresh_timer)'
    substituteInPlace src/slic3r/GUI/MultiMachineManagerPage.cpp \
      --replace-fail 'wxTimerEvent(*m_refresh_timer)' 'wxTimerEvent(*m_flipping_timer)'
    substituteInPlace src/slic3r/GUI/MultiTaskManagerPage.cpp \
      --replace-fail 'wxTimerEvent(*m_refresh_timer)' 'wxTimerEvent(*m_flipping_timer)'
    substituteInPlace src/slic3r/GUI/Widgets/AMSItem.cpp \
      --replace-fail 'wxTimerEvent(*m_refresh_timer)' 'wxTimerEvent(*m_playing_timer)'
    substituteInPlace src/slic3r/GUI/Widgets/SideTools.cpp \
      --replace-fail 'wxDefaultSize,wxALIGN_CENTER_HORIZONTAL | wxST_ELLIPSIZE_END);' \
                     'wxDefaultSize,wxHL_ALIGN_CENTRE);'
    substituteInPlace src/slic3r/GUI/Widgets/AMSControl.cpp \
      --replace-fail 'wxID_ANY, wxEmptyString, wxEmptyString, wxDefaultPosition' \
                     'wxID_ANY, wxT(" "), wxEmptyString, wxDefaultPosition'
    substituteInPlace src/slic3r/GUI/CalibrationWizardPresetPage.cpp \
      --replace-fail 'm_top_sizer->Add(m_pa_cali_method_combox, 0);' \
                     'if (m_pa_cali_method_combox) m_top_sizer->Add(m_pa_cali_method_combox, 0);'
    substituteInPlace src/slic3r/GUI/PresetComboBoxes.cpp \
      --replace-fail 'GList* cells = gtk_cell_layout_get_cells(GTK_CELL_LAYOUT(m_widget));' \
                     'GList* cells = GTK_IS_CELL_LAYOUT(m_widget) ? gtk_cell_layout_get_cells(GTK_CELL_LAYOUT(m_widget)) : nullptr;'
    sed -i '1i#include <wx/event.h>' src/slic3r/Anycubic/AnycubicContext.hpp
    sed -i '1i#include <boost/preprocessor/stringize.hpp>' \
      src/slic3r/Anycubic/plugins/app/detail/app_plugin.hpp \
      src/slic3r/Anycubic/plugins/downloader/detail/downloader_plugin.hpp
    sed -i '1i#include <wx/filename.h>' \
      src/slic3r/Anycubic/plugins/downloader/detail/downloader_plugin.hpp
    sed -i '1i#include <boost/property_tree/json_parser.hpp>' \
      src/slic3r/Anycubic/plugins/app/detail/app_plugin.cpp
    sed -i '1i#include <mutex>' \
      src/slic3r/Anycubic/plugins/home_dialog/detail/home_dialog.hpp
    sed -i '1i#include <boost/preprocessor/stringize.hpp>' \
      src/slic3r/Anycubic/plugins/home_dialog/detail/home_dialog.hpp
    sed -i '1i#include <wx/wupdlock.h>' \
      src/slic3r/Anycubic/plugins/home_dialog/detail/AcDialog.cpp
    sed -i '1i#include <wx/filename.h>' \
      src/slic3r/Anycubic/plugins/downloader/detail/protocol/protocol.cpp
    sed -i '1i#include <wx/time.h>' \
      src/slic3r/Anycubic/plugins/downloader/detail/protocol/protocol.cpp
    sed -i '1i#include <boost/preprocessor/stringize.hpp>' \
      src/slic3r/Anycubic/plugins/httpclient/detail/httpclient_plugin.hpp
    sed -i '1i#include <wx/wfstream.h>' \
      src/slic3r/Anycubic/plugins/httpclient/detail/httpclient_plugin.cpp
    sed -i '1i#include <boost/filesystem.hpp>' \
      src/slic3r/Anycubic/plugins/info_manage/info_manage_plugin.hpp
    sed -i '1i#include <mutex>' \
      src/slic3r/Anycubic/plugins/info_manage/info_manage_plugin.hpp
    sed -i '1i#include <boost/preprocessor/stringize.hpp>' \
      src/slic3r/Anycubic/plugins/info_manage/info_manage_plugin.hpp
    sed -i '1i#include <libslic3r/format.hpp>' \
      src/slic3r/Anycubic/plugins/info_manage/info_manage_plugin.cpp
    sed -i '1i#include <wx/dir.h>' \
      src/slic3r/Anycubic/plugins/info_manage/info_manage_plugin.cpp
    sed -i '1i#include <wx/log.h>' \
      src/slic3r/Anycubic/plugins/xrc/detail/xrc_pluigns.cpp
    sed -i '1i#include <wx/utils.h>' \
      src/slic3r/Anycubic/protocol/check_protocol.cpp
    sed -i '1i#include <cstdint>' \
      src/slic3r/Anycubic/plugins/xrc/detail/widgets/custom_struct_manger.hxx
    substituteInPlace src/slic3r/Anycubic/protocol/check_protocol.cpp \
      --replace-fail 'libslic3r/SemVer.hpp' 'libslic3r/Semver.hpp'
    sed -i '1i#include <wx/string.h>' \
      src/slic3r/Anycubic/plugins/preferences/detail/preferences_plugin.hpp
    sed -i '1i#include <string>' \
      src/slic3r/Anycubic/plugins/utility/utility_plugin.hpp
    sed -i '1i#include <mutex>' \
      src/slic3r/Anycubic/plugins/utility/utility_plugin.hpp
    substituteInPlace src/slic3r/GUI/DeviceManager.hpp src/slic3r/GUI/DeviceManager.cpp \
      --replace-fail 'get_module_name(' 'get_module_name_for_module('
    substituteInPlace src/slic3r/GUI/MainFrame.cpp \
      --replace-fail 'if(auto idx = m_tabpanel->FindPage(m_printer_view);idx!=wxNOT_FOUND){' \
                     'if (m_tabpanel->FindPage(m_printer_view) == wxNOT_FOUND) {'
    substituteInPlace src/slic3r/Anycubic/AnycubicContext.cpp \
      --replace-fail 'append_env("LD_LIBRARY_PATH", current_dir)' \
                     'append_env("LD_LIBRARY_PATH", current_dir.ToUTF8().data())' \
      --replace-fail 'if (!::wxFileExists(current_dir)) {' \
                     'if (!::wxDirExists(current_dir)) {'
    sed -i '/if (!::wxDirExists(current_dir)) {/i\
      wxFileName::Mkdir(package, wxS_DIR_DEFAULT, wxPATH_MKDIR_FULL);\
      wxFileName::Mkdir(current_dir, wxS_DIR_DEFAULT, wxPATH_MKDIR_FULL);' \
      src/slic3r/Anycubic/AnycubicContext.cpp
    sed -i '/load_files(wxArrayString/c\
            this->load_files([target_path]() { wxArrayString files; files.Add(from_u8(target_path.string())); return files; }());' \
      src/slic3r/GUI/Plater.cpp
    # The bitmap helpers accept a null window, but dereference it directly.
    # em_unit() already handles nullptr by using the app-wide scale.
    substituteInPlace src/slic3r/GUI/wxExtensions.cpp \
      --replace-fail 'unsigned int height = (unsigned int) (win->FromDIP(px_cnt) + 0.5f);' \
                     'unsigned int height = (unsigned int) (px_cnt * em_unit(win) / 10.0f + 0.5f);' \
      --replace-fail 'resize ? win->FromDIP(10) * 0.1f : 0.f' \
                     'resize ? em_unit(win) * 0.1f : 0.f' \
      --replace-fail 'unsigned int height = (unsigned int)(win->FromDIP(px_cnt) + 0.5f);' \
                     'unsigned int height = (unsigned int)(px_cnt * em_unit(win) / 10.0f + 0.5f);'
    substituteInPlace src/slic3r/GUI/BBLTopbar.cpp \
      --replace-fail 'item.GetDisabledBitmap()' 'item.GetDisabledBitmapFor(wnd)' \
      --replace-fail 'item.GetBitmap();' 'item.GetBitmapFor(wnd);'
    substituteInPlace src/slic3r/GUI/Widgets/DropDown.cpp \
      --replace-fail 'auto size2 = GetBmpSize(icon);' \
                     'auto size2 = icon.IsOk() ? GetBmpSize(icon) : wxSize(0, 0);'
    # wxTextCtrl rejects SetLabel() in wxWidgets 3.3; programmatic text
    # updates must use ChangeValue() to avoid firing text events recursively.
    substituteInPlace src/slic3r/GUI/CalibrationWizardSavePage.cpp \
      --replace-fail 'GetTextCtrl()->SetLabel(' 'GetTextCtrl()->ChangeValue('
    substituteInPlace src/slic3r/GUI/Field.cpp \
      --replace-fail 'GetTextCtrl()->SetLabel(' 'GetTextCtrl()->ChangeValue(' \
      --replace-fail 'text_ctrl->SetLabel(text_value);' 'text_ctrl->ChangeValue(text_value);' \
      --replace-fail 'm_textctrl->SetLabel(wxString::Format' 'm_textctrl->ChangeValue(wxString::Format'
    sed -i '0,/    temp->SetLabel(_L(m_opt.sidetext));/s|    temp->SetLabel(_L(m_opt.sidetext));|    if (m_opt.multiline) static_cast<wxTextCtrl*>(temp)->SetHint(_L(m_opt.sidetext)); else temp->SetLabel(_L(m_opt.sidetext));|' \
      src/slic3r/GUI/Field.cpp
    substituteInPlace src/slic3r/GUI/Widgets/DropDown.cpp \
      --replace-fail 'gtk_window_resize (GTK_WINDOW (m_widget), szContent.x, szContent.y);' \
                     'if (szContent.x > 0 && szContent.y > 0) gtk_window_resize (GTK_WINDOW (m_widget), szContent.x, szContent.y);'
    # wxGTK asserts if a static bitmap is measured before it receives a real
    # bitmap. The device status panel creates these controls before printer
    # status arrives, so seed them with their normal/offline artwork.
    substituteInPlace src/slic3r/GUI/StatusPanel.cpp \
      --replace-fail 'm_bitmap_sdcard_img = new wxStaticBitmap(m_panel_monitoring_title, wxID_ANY, wxNullBitmap' \
                     'm_bitmap_sdcard_img = new wxStaticBitmap(m_panel_monitoring_title, wxID_ANY, m_bitmap_sdcard_state_no.bmp()' \
      --replace-fail 'm_bitmap_timelapse_img = new wxStaticBitmap(m_panel_monitoring_title, wxID_ANY, wxNullBitmap' \
                     'm_bitmap_timelapse_img = new wxStaticBitmap(m_panel_monitoring_title, wxID_ANY, m_bitmap_timelapse_off.bmp()' \
      --replace-fail 'm_bitmap_recording_img = new wxStaticBitmap(m_panel_monitoring_title, wxID_ANY, wxNullBitmap' \
                     'm_bitmap_recording_img = new wxStaticBitmap(m_panel_monitoring_title, wxID_ANY, m_bitmap_recording_off.bmp()' \
      --replace-fail 'm_bitmap_vcamera_img = new wxStaticBitmap(m_panel_monitoring_title, wxID_ANY, wxNullBitmap' \
                     'm_bitmap_vcamera_img = new wxStaticBitmap(m_panel_monitoring_title, wxID_ANY, m_bitmap_vcamera_off.bmp()' \
      --replace-fail 'm_camera_switch_button = new wxStaticBitmap(m_panel_monitoring_title, wxID_ANY, wxNullBitmap' \
                     'm_camera_switch_button = new wxStaticBitmap(m_panel_monitoring_title, wxID_ANY, m_bitmap_switch_camera.bmp()'
    substituteInPlace src/slic3r/GUI/NetworkTestDialog.cpp \
      --replace-fail 'wxString::Format("%s:", buf.str())' \
                     'wxString::Format("%s:", wxString::FromUTF8(buf.str()))' \
      --replace-fail 'wxString::Format("test %s ip resolved = %s", name, ip)' \
                     'wxString::Format("test %s ip resolved = %s", name, wxString::FromUTF8(ip))' \
      --replace-fail 'wxString::Format("status=%u, body=%s, error=%s", status, body, error)' \
                     'wxString::Format("status=%u, body=%s, error=%s", status, wxString::FromUTF8(body), wxString::FromUTF8(error))'
    # This status message has no format placeholders; passing closeCount makes
    # wxArgNormalizer raise an assertion after a successful IP connection.
    substituteInPlace src/slic3r/GUI/ReleaseNote.cpp \
      --replace-fail 'wxString::Format(_L("Connecting to printer... The dialog will close later"), closeCount)' \
                     '_L("Connecting to printer... The dialog will close later")'
    substituteInPlace src/slic3r/GUI/DeviceTab/uiDeviceUpdateVersion.cpp \
      --replace-fail 'm_dev_upgrade_indicator = new wxStaticBitmap(this, wxID_ANY, wxNullBitmap, wxDefaultPosition, wxSize(FromDIP(5), FromDIP(5)));' \
                     'm_dev_upgrade_indicator = new wxStaticBitmap(this, wxID_ANY, ScalableBitmap(this, "monitor_upgrade_online", 5).bmp(), wxDefaultPosition, wxSize(FromDIP(5), FromDIP(5)));'
    sed -i '/m_dev_upgrade_indicator->SetBitmap(ScalableBitmap(this, "monitor_upgrade_online", 5).bmp());/d' \
      src/slic3r/GUI/DeviceTab/uiDeviceUpdateVersion.cpp
    # Project opening from the Home webview must show the Plater first: its
    # file dialog and project-loading UI are parented to the Plater itself.
    substituteInPlace src/slic3r/GUI/GUI_App.cpp \
      --replace-fail '    if (project_id == "<new>")
        plater()->new_project();
    else if (project_id.empty())
        plater()->load_project();' \
                     '    if (project_id == "<new>") {
        CallAfter([this] {
            if (mainframe) mainframe->select_tab(MainFrame::tp3DEditor);
            plater()->new_project();
        });
    } else if (project_id.empty()) {
        CallAfter([this] {
            if (mainframe) mainframe->select_tab(MainFrame::tp3DEditor);
            plater()->load_project();
        });
    }' \
      --replace-fail '    else
        CallAfter([this, project_id] { mainframe->open_recent_project(-1, wxString::FromUTF8(project_id)); });' \
                     '    else {
        CallAfter([this, project_id] {
            if (mainframe) mainframe->select_tab(MainFrame::tp3DEditor);
            mainframe->open_recent_project(-1, wxString::FromUTF8(project_id));
        });
    }'
    # wxGTK 3.3.4 can report this specific top-level-window assertion when a
    # native file dialog is dragged. Keep other wx assertions visible.
    substituteInPlace src/slic3r/GUI/GUI_App.hpp \
      --replace-fail '    bool            OnInit() override;' \
                     '    void            OnAssertFailure(const wxChar *file, int line, const wxChar *func, const wxChar *cond, const wxChar *msg) override;
    bool            OnInit() override;'
    substituteInPlace src/slic3r/GUI/GUI_App.cpp \
      --replace-fail 'bool GUI_App::OnInit()
{' \
                     'void GUI_App::OnAssertFailure(const wxChar *file, int line, const wxChar *func, const wxChar *cond, const wxChar *msg)
{
    const wxString source(file ? file : wxS(""));
    const wxString function(func ? func : wxS(""));
    const wxString condition(cond ? cond : wxS(""));
    const wxString message(msg ? msg : wxS(""));
    if (source.EndsWith(wxS("/src/gtk/toplevel.cpp")) && line == 1568 &&
        function == wxS("DoMoveWindow") && condition == wxS("Assert failure") &&
        message == wxS("DoMoveWindow called for wxTopLevelWindowGTK"))
        return;
    wxApp::OnAssertFailure(file, line, func, cond, msg);
}

bool GUI_App::OnInit()
{'
    # OCCT 7.9 consolidated the legacy STEP libraries into TKDESTEP, and
    # nixpkgs builds OpenCV as component libraries rather than opencv_world.
    substituteInPlace src/libslic3r/CMakeLists.txt \
      --replace-fail 'TKXDESTEP' 'TKDESTEP' \
      --replace-fail 'TKSTEP209' 'TKDESTEP' \
      --replace-fail 'TKSTEPAttr' 'TKDESTEP' \
      --replace-fail 'TKSTEPBase' 'TKDESTEP' \
      --replace-fail 'TKSTEP' 'TKDESTEP' \
      --replace-fail 'opencv_world' 'opencv_core opencv_imgproc opencv_imgcodecs'
    substituteInPlace src/slic3r/CMakeLists.txt \
      --replace-fail 'pkg_check_modules(LIBSECRET REQUIRED libsecret-1)' \
                     'pkg_check_modules(LIBSECRET REQUIRED libsecret-1)
    pkg_check_modules(WEBKIT2GTK REQUIRED IMPORTED_TARGET webkit2gtk-4.1)
    target_link_libraries(libslic3r_gui PUBLIC PkgConfig::WEBKIT2GTK)'
    substituteInPlace src/slic3r/GUI/PhysicalPrinterDialog.cpp \
      --replace-fail 'choice->set_values({ m_config->opt_string("printhost_port") });' \
                     'choice->set_values(std::vector<std::string>{ m_config->opt_string("printhost_port") });'
    substituteInPlace src/libslic3r/GCode/PostProcessor.cpp \
      src/slic3r/GUI/RemovableDriveManager.cpp \
      src/slic3r/GUI/MediaPlayCtrl.cpp \
      --replace-fail '#include <boost/process.hpp>' '#include <boost/process/v1.hpp>'

    # Boost 1.91 BoostConfig.cmake does not provide component config files.
    # Use FindBoost module instead.
    cp ${./FindBoost.cmake} cmake/modules/FindBoost.cmake
    substituteInPlace CMakeLists.txt \
      --replace-fail 'find_package(Boost 1.83.0 CONFIG REQUIRED COMPONENTS' \
                     'list(PREPEND CMAKE_MODULE_PATH "''${PROJECT_SOURCE_DIR}/cmake/modules")
    set(Boost_NO_BOOST_CMAKE ON)
    find_package(Boost 1.83.0 MODULE REQUIRED COMPONENTS' \
      --replace-fail 'list(APPEND CMAKE_MODULE_PATH ''${PROJECT_SOURCE_DIR}/cmake/modules/)' \
                     'list(PREPEND CMAKE_MODULE_PATH ${openvdb}/lib/cmake/OpenVDB ''${PROJECT_SOURCE_DIR}/cmake/modules/)'
    substituteInPlace CMakeLists.txt \
      --replace-fail $'add_subdirectory(deps_src)\nadd_subdirectory(src)' \
                     'add_subdirectory(deps_src)
    add_subdirectory(open-plugins)
    foreach(_openplugins_component ACWebView plugins_manager plugins_base easy_log utility event_sdk constant)
      if(NOT TARGET ''${_openplugins_component})
        message(FATAL_ERROR "OpenPlugins component ''${_openplugins_component} was not built")
      endif()
    target_include_directories(''${_openplugins_component} PUBLIC "''${CMAKE_CURRENT_SOURCE_DIR}/open-plugins" "''${CMAKE_CURRENT_SOURCE_DIR}/open-plugins/3rdparty")
      add_library(OpenPlugins::''${_openplugins_component} ALIAS ''${_openplugins_component})
    endforeach()
    add_subdirectory(src)'
    substituteInPlace cmake/modules/FindOpenVDB.cmake \
      --replace-fail 'find_package(IlmBase QUIET)' \
                     'find_package(IlmBase QUIET)
    find_package(Imath CONFIG QUIET)
    if(TARGET Imath::Imath AND NOT TARGET IlmBase::Half)
      add_library(IlmBase::Half INTERFACE IMPORTED)
      target_link_libraries(IlmBase::Half INTERFACE Imath::Imath)
      set(IlmBase_FOUND TRUE)
    endif()'
  '';

  buildPhase = ''
    runHook preBuild
    cmake -S ${libnoiseSrc} -B libnoise-build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_INSTALL_PREFIX="$PWD/libnoise-prefix"
    cmake --build libnoise-build --parallel "$NIX_BUILD_CORES"
    cmake --install libnoise-build
    mkdir build
    cd build
    cmake .. \
      -DCMAKE_INSTALL_PREFIX="$out" \
      -DCMAKE_PREFIX_PATH="$PWD/../libnoise-prefix;${openvdb}/lib/cmake/OpenVDB" \
      -DCMAKE_MODULE_PATH="$PWD/../cmake/modules;${openvdb}/lib/cmake/OpenVDB" \
      -DBoost_NO_BOOST_CMAKE=ON \
      -DLIBNOISE_INCLUDE_DIR="$PWD/../libnoise-prefix/include" \
      -DLIBNOISE_LIBRARY="$PWD/../libnoise-prefix/lib/liblibnoise_static.a" \
      -DCMAKE_BUILD_TYPE=Release \
      -DSLIC3R_STATIC=0 \
      -DSLIC3R_GUI=1 \
      -DSLIC3R_GTK=3 \
      -DENABLE_BBS_TAB=ON \
      -DSLIC3R_PCH=OFF \
      -DImath_DIR=${imath}/lib/cmake/Imath \
      "-DCMAKE_CXX_FLAGS=-I${opencv}/include/opencv4 -I${wxwidgetsSrc}/include -include boost/preprocessor/stringize.hpp -Wno-error=return-type -Wno-error=maybe-uninitialized" \
      -G Ninja
    cmake --build . --target all -- -j$NIX_BUILD_CORES
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cmake --install . --prefix "$out"
    runHook postInstall
  '';

  postFixup = ''
    # Anycubic resolves its Linux resources from a capitalized Resources
    # directory beside the executable.
    ln -s ../resources "$out/bin/Resources"
    wrapProgram "$out/bin/AnycubicSlicerNext" \
      --set WXSUPPRESS_SIZER_FLAGS_CHECK 1 \
      --prefix LD_LIBRARY_PATH : "$out/lib" \
      --unset GTK_PATH
    ln -s AnycubicSlicerNext "$out/bin/orca-slicer"
    install -Dm644 "$out/resources/images/AnycubicSlicer.png" \
      "$out/share/icons/hicolor/256x256/apps/AnycubicSlicer.png"
    install -Dm644 /dev/null "$out/share/applications/anycubic-slicer-next.desktop"
    printf '%s\n' \
      '[Desktop Entry]' \
      'Type=Application' \
      'Name=AnycubicSlicerNext' \
      'Comment=Anycubic 3D printer slicer' \
      "Exec=$out/bin/AnycubicSlicerNext %F" \
      "Icon=$out/resources/images/AnycubicSlicer.png" \
      'Terminal=false' \
      'Categories=Graphics;3DGraphics;' \
      'StartupWMClass=AnycubicSlicerNext' \
      > "$out/share/applications/anycubic-slicer-next.desktop"
    rm -f "$out/resources/applications/OrcaSlicer.desktop"
  '';

  inherit src;

  dontConfigure = true;

  meta = with lib; {
    description = "Anycubic 3D printer slicer - fork of OrcaSlicer";
    homepage = "https://github.com/ANYCUBIC-3D/AnycubicSlicerNext";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    maintainers = with maintainers; [];
  };
})
