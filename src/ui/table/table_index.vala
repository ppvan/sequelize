

namespace Psequel {

    [GtkTemplate (ui = "/me/ppvan/psequel/gtk/table-index.ui")]
    public class TableIndexInfo : Adw.Bin {

        public ObservableList<Index> indexes;


        public TableIndexInfo () {
            Object ();
        }

        construct {
            debug ("[CONTRUCT] %s", this.name);
            setup_name_col ();
            setup_indexcolumns_col ();
            setup_indextype_col ();
            setup_unique_col ();
            setup_indexsize_col ();
        }


        private void setup_name_col () {
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((listitem) => {
                var label = new Gtk.Label (null);
                label.halign = Gtk.Align.START;
                listitem.child = label;
            });
            factory.bind.connect ((listitem) => {
                var item = listitem.item as Index;
                var label = listitem.child as Gtk.Label;
                label.label = item.name;
            });
            var col = new Gtk.ColumnViewColumn ("Index Name", factory);
            col.fixed_width = 250;
            view.append_column (col);
        }

        private void setup_indextype_col () {
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((listitem) => {
                var label = new Gtk.Label (null);
                label.halign = Gtk.Align.CENTER;

                listitem.child = label;
            });
            factory.bind.connect ((listitem) => {
                var item = listitem.item as Index;
                var label = listitem.child as Gtk.Label;
                label.label = item.index_type.to_string ();
            });
            var col = new Gtk.ColumnViewColumn ("Index Type", factory);
            col.fixed_width = 80;
            view.append_column (col);
        }

        private void setup_unique_col () {
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((listitem) => {
                var label = new Gtk.Label (null);
                listitem.child = label;
            });
            factory.bind.connect ((listitem) => {
                var item = listitem.item as Index;
                var label = listitem.child as Gtk.Label;
                label.label = item.unique ? "YES" : "NO";
            });
            var col = new Gtk.ColumnViewColumn ("Unique", factory);
            col.fixed_width = 70;

            view.append_column (col);
        }

        private void setup_indexcolumns_col () {
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((listitem) => {
                var label = new Gtk.Label (null);
                label.halign = Gtk.Align.START;
                label.margin_end = 4;
                label.margin_start = 4;
                listitem.child = label;
            });
            factory.bind.connect ((listitem) => {
                var item = listitem.item as Index;
                var label = listitem.child as Gtk.Label;
                label.label = item.columns;
            });
            var col = new Gtk.ColumnViewColumn ("Index Columns", factory);
            col.expand = true;
            view.append_column (col);
        }

        private void setup_indexsize_col () {
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((listitem) => {
                var label = new Gtk.Label (null);
                label.halign = Gtk.Align.END;
                label.margin_end = 4;
                label.margin_start = 4;
                listitem.child = label;
            });
            factory.bind.connect ((listitem) => {
                var item = listitem.item as Index;
                var label = listitem.child as Gtk.Label;
                label.label = item.size;
            });
            var col = new Gtk.ColumnViewColumn ("Index Size", factory);
            col.fixed_width = 70;
            view.append_column (col);
        }


        [GtkChild]
        private unowned Gtk.ColumnView view;
    }
}