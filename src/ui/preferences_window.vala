namespace Psequel {

    [GtkTemplate (ui = "/me/ppvan/psequel/gtk/preferences.ui")]
    public class PreferencesWindow : Adw.PreferencesWindow {

        private Settings settings;
        private Gtk.StringList model;

        public PreferencesWindow () {
            Object ();
        }

        construct {
            settings = ResourceManager.instance ().settings;
            setup_binding ();
            defaults ();
        }


        private void defaults () {
            var desc = Pango.FontDescription.from_string (settings.get_string ("editor-font"));

            font_label.get_pango_context ().set_font_description (desc);
            font_label.label = desc.to_string ();

            var style_manager = GtkSource.StyleSchemeManager.get_default ();

            this.model = new Gtk.StringList (style_manager.get_scheme_ids ());

            color_scheme.set_model (this.model);
        }

        private void setup_binding () {
            // settings.bind_with_mapping (string key, GLib.Object object, string property, GLib.SettingsBindFlags flags, GLib.SettingsBindGetMappingShared get_mapping, GLib.SettingsBindSetMappingShared set_mapping, void* user_data, GLib.DestroyNotify? notify)
            settings.bind ("query-limit", query_limit, "value", SettingsBindFlags.DEFAULT);
            settings.bind ("query-timeout", query_timeout, "value", SettingsBindFlags.DEFAULT);
            settings.bind ("connection-timeout", conn_timeout, "value", SettingsBindFlags.DEFAULT);

            settings.changed["editor-font"].connect ((_setting, key) => {

                var desc = Pango.FontDescription.from_string (_setting.get_string (key));

                font_label.get_pango_context ().set_font_description (desc);
            });

            settings.changed["color-scheme"].connect ((_setting, key) => {
                
                var cur_color_scheme = _setting.get_string (key);
                
                for (uint i = 0; i < this.model.get_n_items (); i++) {
                    var item = this.model.get_item (i) as Gtk.StringObject;
                    if (item.string == cur_color_scheme) {
                        color_scheme.selected = i;
                        break;
                    }
                }
            });

            color_scheme.notify["selected"].connect (() => {
                var item = color_scheme.get_selected_item () as Gtk.StringObject;
                settings.set_string ("color-scheme", item.string);
            });
        }

        [GtkCallback]
        private void on_font_chooser (Adw.ActionRow row) {
            old_choser ();
        }

        private void old_choser () {
            /* Create dialog */
            var dialog = new Gtk.FontChooserDialog (_("Select font"), this) {
                modal = true,
                transient_for = this,
                level = Gtk.FontChooserLevel.FAMILY | Gtk.FontChooserLevel.SIZE | Gtk.FontChooserLevel.STYLE,
            };

            dialog.set_filter_func ((desc) => {
                return desc.is_monospace ();
            });


            /* Set font and close dialog on response */
            dialog.response.connect ((res) => {
                if (res == Gtk.ResponseType.OK && dialog.font != null) {
                    font_label.get_pango_context ().set_font_description (dialog.font_desc);
                    font_label.label = dialog.font_desc.to_string ();

                    settings.set_string ("editor-font", dialog.font_desc.to_string ());
                }

                dialog.close ();
            });


            /* Show dialog */
            dialog.present ();
        }

        private void new_choser () {
            var dialog = new Gtk.FontDialog () {
                modal = true,
                title = _("Select Font"),
            };

            var init = new Pango.FontDescription ();
            init.set_family ("Roboto Regular");
            init.set_size (14);

            dialog.choose_font.begin (this, init, null, (obj, res) => {
                var val = dialog.choose_font.end (res);

                font_label.get_pango_context ().set_font_description (val);
                font_label.label = val.get_family ();
            });
        }

        [GtkChild]
        private unowned Gtk.Label font_label;

        [GtkChild]
        private unowned Gtk.SpinButton conn_timeout;

        [GtkChild]
        private unowned Gtk.SpinButton query_timeout;

        [GtkChild]
        private unowned Gtk.SpinButton query_limit;

        [GtkChild]
        private unowned Adw.ComboRow color_scheme;
    }
}