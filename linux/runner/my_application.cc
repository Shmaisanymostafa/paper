#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* documents;
  GPtrArray* pending;
  gboolean document_ready;
  guint outstanding;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// A unique GApplication forwards subsequent launches to this process over D-Bus.
static void document_method(FlMethodChannel* channel, FlMethodCall* call, gpointer data) {
  MyApplication* self = MY_APPLICATION(data);
  const gchar* name = fl_method_call_get_name(call);
  if (g_strcmp0(name, "ready") == 0) {
    self->document_ready = TRUE;
    g_autoptr(FlValue) paths = fl_value_new_list();
    for (guint i = 0; i < self->pending->len; ++i) {
      fl_value_append_take(paths, fl_value_new_string(static_cast<const gchar*>(g_ptr_array_index(self->pending, i))));
    }
    g_ptr_array_set_size(self->pending, 0);
    fl_method_call_respond_success(call, paths, nullptr);
  } else if (g_strcmp0(name, "release") == 0) {
    // Linux paths are originals; never remove them.
    if (self->outstanding > 0) --self->outstanding;
    fl_method_call_respond_success(call, nullptr, nullptr);
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* existing = gtk_application_get_active_window(GTK_APPLICATION(application));
  if (existing != nullptr) { gtk_window_present(existing); return; }
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "cave_paper");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "cave_paper");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->documents = fl_method_channel_new(fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "technology.cave.paper/documents", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->documents, document_method, self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Paths are resolved using the invoking process's working directory, including remote launches.
static int my_application_command_line(GApplication* application, GApplicationCommandLine* command) {
  MyApplication* self = MY_APPLICATION(application);
  g_application_activate(application);
  int count = 0;
  g_auto(GStrv) arguments = g_application_command_line_get_arguments(command, &count);
  for (int i = 1; i < count && i <= 32; ++i) {
    if (g_strcmp0(arguments[i], "--") == 0) continue;
    g_autoptr(GFile) file = g_application_command_line_create_file_for_arg(command, arguments[i]);
    g_autofree gchar* path = g_file_get_path(file);
    if (path == nullptr) continue; // Reject remote URLs, never fetch network documents.
    g_autofree gchar* lower = g_ascii_strdown(path, -1);
    if (!g_str_has_suffix(lower, ".pdf") || self->outstanding >= 32) continue;
    ++self->outstanding;
    if (self->document_ready) {
      g_autoptr(FlValue) value = fl_value_new_string(path);
      fl_method_channel_invoke_method(self->documents, "open", value, nullptr, nullptr, nullptr);
    } else if (self->pending->len < 32) {
      g_ptr_array_add(self->pending, g_strdup(path));
    }
  }
  return 0;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->documents);
  g_clear_pointer(&self->pending, g_ptr_array_unref);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->command_line = my_application_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->pending = g_ptr_array_new_with_free_func(g_free);
}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_HANDLES_COMMAND_LINE, nullptr));
}
