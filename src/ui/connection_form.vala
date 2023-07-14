namespace Sequelize {

    [GtkTemplate (ui = "/me/ppvan/sequelize/gtk/connection-form.ui")]
    public class ConnectionForm : Gtk.Box {

        BindingGroup binddings;

        private unowned QueryService query_service;

        private Connection _conn;
        public Connection mapped_conn {
            get {
                return _conn;
            }
            set {
                _conn = value;
                binddings.source = _conn;
            }
        }

        public ConnectionSidebar sidebar { get; set; }

        public ConnectionForm () {
            Object ();
        }

        construct {
            // init service
            query_service = ResourceManager.instance ().query_service;

            // Create group to maped the entry widget to connection data.
            this.binddings = new BindingGroup ();
            set_up_bindings (binddings);
        }

        private void set_up_bindings (BindingGroup group) {
            debug ("set_up connection form bindings group");

            group.bind ("name", name_entry, "text", SYNC_CREATE | BIDIRECTIONAL);
            group.bind ("host", host_entry, "text", SYNC_CREATE | BIDIRECTIONAL);
            group.bind ("port", port_entry, "text", SYNC_CREATE | BIDIRECTIONAL);
            group.bind ("user", user_entry, "text", SYNC_CREATE | BIDIRECTIONAL);
            group.bind ("password", password_entry, "text", SYNC_CREATE | BIDIRECTIONAL);
            group.bind ("database", database_entry, "text", SYNC_CREATE | BIDIRECTIONAL);
            group.bind ("use_ssl", ssl_switch, "active", SYNC_CREATE | BIDIRECTIONAL);


            connect_btn.bind_property ("sensitive", spinner, "spinning", BindingFlags.INVERT_BOOLEAN);

            password_entry.bind_property ("text",
                                          password_entry,
                                          "show-peek-icon",
                                          BindingFlags.SYNC_CREATE,
                                          (binding, from_value, ref to_value) => {

                string text = from_value.get_string ();
                to_value.set_boolean (text.length > 0);

                return true;
            });

            debug ("set_up binddings done");
        }

        [GtkCallback]
        private void on_connect_clicked (Gtk.Button btn) {
            // name_entry.buffer.text = "Hello world";
            // i want to save it
            // btn.set_sensitive (false);
            debug ("Connecting to %s", mapped_conn.url_form ());

            TimePerf.begin ();
            with (ResourceManager.instance ()) {

                btn.sensitive = false;
                query_service.connect_db_async.begin (mapped_conn, (obj, res) => {
                    btn.sensitive = true;
                    TimePerf.end ();

                    var tmp = obj as QueryService;
                    string err = null;
                    tmp.connect_db_async.end (res, out err);

                    if (err != null) {
                        var dialog = create_err_dialog ("Connection error", err);
                        dialog.present ();
                    }
                });
            }
        }

        private Adw.MessageDialog create_err_dialog (string heading, string body) {
            var window = ResourceManager.instance ().app.active_window;
            var dialog = new Adw.MessageDialog (window, heading, body);

            dialog.close_response = "okay";
            dialog.add_response ("okay", "OK");

            return dialog;
        }

        [GtkCallback]
        private void on_entry_activated (Gtk.Entry entry) {
            connect_btn.clicked ();
        }

        [GtkChild]
        unowned Gtk.Button connect_btn;

        [GtkChild]
        unowned Gtk.Spinner spinner;

        [GtkChild]
        private unowned Gtk.Entry name_entry;

        [GtkChild]
        private unowned Gtk.Entry host_entry;
        [GtkChild]
        private unowned Gtk.Entry port_entry;
        [GtkChild]
        private unowned Gtk.Entry user_entry;
        [GtkChild]
        private unowned Gtk.PasswordEntry password_entry;

        [GtkChild]
        private unowned Gtk.Entry database_entry;

        [GtkChild]
        private unowned Gtk.Switch ssl_switch;
    }
}