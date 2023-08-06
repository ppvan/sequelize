
namespace Psequel {
    public class SchemaService : Object {

        // Order of column is important, check the load_columns if you want to change query
        public const string COLUMN_SQL = """
        SELECT column_name, table_name,
        case 
            when domain_name is not null then domain_name
            when data_type='character varying' THEN 'varchar('||character_maximum_length||')'
            when data_type='numeric' THEN 'numeric('||numeric_precision||','||numeric_scale||')'
            else data_type
        end as data_type,
        is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = $1;
        """;
        public const string INDEX_SQL = """
        SELECT indexname, tablename, pg_size_pretty(pg_relation_size(indexname::regclass)) as size, indexdef
        FROM pg_indexes
        WHERE schemaname = $1;
        """;
        public const string FK_SQL = """
        SELECT con.conname, rel.relname, pg_catalog.pg_get_constraintdef(con.oid, true) as condef
        FROM pg_catalog.pg_constraint con
             INNER JOIN pg_catalog.pg_class rel
                        ON rel.oid = con.conrelid
             INNER JOIN pg_catalog.pg_namespace nsp
                        ON nsp.oid = connamespace
        WHERE con.contype = 'f' AND nsp.nspname = $1;
        """;
        public const string TB_SQL = """
        SELECT tablename FROM pg_tables WHERE schemaname=$1;
        """;
        public const string VIEW_SQL = """
        SELECT table_name FROM INFORMATION_SCHEMA.views WHERE table_schema = $1;
        """;

        public const string SCHEMA_LIST_SQL = """
        SELECT schema_name 
        FROM information_schema.schemata;
        """;

        private QueryService query_service;

        public SchemaService (QueryService service) {
            this.query_service = service;
        }

        public async string[] schema_list () throws PsequelError {
            var relation = yield query_service.exec_query (SCHEMA_LIST_SQL);

            var _schema_list = new string[relation.rows];

            for (int i = 0; i < _schema_list.length; i++) {
                _schema_list[i] = relation[i][0];
            }

            return _schema_list;
        }

        public async List<Schema> get_schemas () {
            var list = new List<Schema> ();
            try {
                var relation = yield query_service.exec_query (SCHEMA_LIST_SQL);

                for (int i = 0; i < relation.rows; i++) {
                    var s = new Schema (relation[i][0]);
                    list.append (s);
                }
            } catch (PsequelError err) {
                debug (err.message);
            }

            return list;
        }

        public async void load_schema (Schema schema) throws PsequelError {
            yield load_tables (schema);
            yield load_views (schema);
        }

        private async void load_views (Schema schema) {
            schema.views.foreach ((item) => {
                schema.views.remove (item);
            });

            var views = yield get_views (schema);

            views.foreach ((item) => {
                schema.views.append (item);
            });
        }

        private async void load_tables (Schema schema) {

            // clear old tables.
            schema.tables.foreach ((item) => {
                schema.tables.remove (item);
            });

            var groups = new HashTable<string, Table> (GLib.str_hash, GLib.str_equal);

            var table_names = yield get_tbnames (schema);
            var columns = yield get_columns (schema);
            var indexes = yield get_indexes (schema);
            var fks = yield get_fks (schema);

            debug ("cols: %u indx: %u fks: %u", columns.length (), indexes.length (), fks.length ());

            table_names.foreach ((tbname) => {
                var table = new Table (schema) {
                    name = tbname,
                };
                groups.insert (tbname, table);
            });

            columns.foreach ((col) => {
                if (groups.contains (col.table)) {
                    var table = groups.get (col.table);
                    table.columns.append (col);
                }
            });

            indexes.foreach ((index) => {
                if (groups.contains (index.table)) {
                    var table = groups.get (index.table);
                    table.indexes.append (index);
                }
            });

            fks.foreach ((fk) => {
                if (groups.contains (fk.table)) {
                    var table = groups.get (fk.table);
                    table.foreign_keys.append (fk);
                }
            });

            var values = groups.steal_all_values ();

            for (int i = 0; i < values.length; i++) {
                schema.tables.append (values[i]);
            }
        }


        private async List<string> get_tbnames (Schema schema) {
            var list = new List<string> ();

            try {
                var relation = yield query_service.exec_query_params (TB_SQL, { new Variant.string (schema.name) });

                foreach (var row in relation) {
                    list.append (row[0]);
                }
            } catch (PsequelError err) {
                debug (err.message);
            }

            return list;
        }

        private async List<View> get_views (Schema schema) {
            var list = new List<View> ();

            try {
                var relation = yield query_service.exec_query_params (VIEW_SQL, { new Variant.string (schema.name) });

                foreach (var row in relation) {
                    var v = new View (schema);
                    v.name = row[0];

                    list.append (v);
                }
            } catch (PsequelError err) {
                debug (err.message);
            }

            return list;
        }

        private async List<Column> get_columns (Schema schema) {

            var list = new List<Column> ();

            try {
                var relation = yield query_service.exec_query_params (COLUMN_SQL, { new Variant.string (schema.name) });

                foreach (var row in relation) {
                    var col = new Column ();
                    col.schemaname = schema.name;
                    col.name = row[0];
                    col.table = row[1];
                    col.column_type = row[2];
                    col.nullable = row[3] == "YES" ? true : false;
                    col.default_val = row[4];

                    list.append (col);
                }
            } catch (PsequelError err) {
                debug (err.message);
            }

            return list;
        }

        private async List<Index> get_indexes (Schema schema) {

            var list = new List<Index> ();

            try {
                var relation = yield query_service.exec_query_params (INDEX_SQL, { new Variant.string (schema.name) });

                foreach (var row in relation) {
                    var index = new Index ();
                    index.schemaname = schema.name;
                    index.name = row[0];
                    index.table = row[1];
                    index.size = row[2];
                    index.indexdef = row[3];

                    list.append (index);
                }
            } catch (PsequelError err) {
                debug (err.message);
            }

            return list;
        }

        private async List<ForeignKey> get_fks (Schema schema) {

            var list = new List<ForeignKey> ();

            try {
                var relation = yield query_service.exec_query_params (FK_SQL, { new Variant.string (schema.name) });

                foreach (var row in relation) {
                    var fk = new ForeignKey ();
                    fk.schemaname = schema.name;
                    fk.name = row[0];
                    fk.table = row[1];
                    fk.fk_def = row[2];

                    list.append (fk);
                }
            } catch (PsequelError err) {
                debug (err.message);
            }

            return list;
        }

        // private async void load_columns (Schema schema) throws PsequelError {

        // var relation = yield query_service.exec_query_params (COLUMN_SQL, { new Variant.string (schema.name) });

        // foreach (var row in relation) {
        // var col = new Column ();
        // col.schemaname = schema.name;
        // col.name = row[0];
        // col.table = row[1];
        // col.column_type = row[2];
        // col.nullable = row[3] == "YES" ? true : false;
        // col.default_val = row[4];
        // schema.columns.add (col);
        // }
        // }

        // private async void load_indexes (Schema schema) throws PsequelError {

        // var relation = yield query_service.exec_query_params (INDEX_SQL, { new Variant.string (schema.name) });

        // foreach (var row in relation) {
        // var index = new Index ();
        // index.schemaname = schema.name;
        // index.name = row[0];
        // index.table = row[1];
        // index.size = row[2];
        // index.indexdef = row[3];

        // schema.indexes.add (index);
        // }
        // }

        // private async void load_fks (Schema schema) throws PsequelError {
        // var relation = yield query_service.exec_query_params (FK_SQL, { new Variant.string (schema.name) });

        // foreach (var row in relation) {
        // var fk = new ForeignKey ();
        // fk.schemaname = schema.name;
        // fk.name = row[0];
        // fk.table = row[1];
        // fk.fk_def = row[2];

        // schema.fks.add (fk);
        // }
        // }

        // private async void load_tbname (Schema schema) throws PsequelError {
        // var relation = yield query_service.exec_query_params (TB_SQL, { new Variant.string (schema.name)});

        // foreach (var row in relation) {
        // schema.tablenames.add (new Gtk.StringObject (row[0]));
        // }
        // }
    }
}