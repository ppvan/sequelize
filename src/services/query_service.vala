using Postgres;

using Gee;
namespace Psequel {
    public class QueryService : Object {

        enum ColumnFormat {
            TEXT = 0,
            BINARY
        }

        public QueryService (ThreadPool<Worker> background) {
            Object ();

            this.background = background;
        }

        public async Table db_schemas () throws PsequelError {
            var stmt = "select schema_name from information_schema.schemata;";

            var res = yield exec_query (stmt);

            return res;
        }

        public async Table db_table_info (string schema, string table_name) throws PsequelError {
            string stmt = """
            SELECT column_name AS "Column Name",
            data_type AS "Type",
            character_maximum_length AS "Length",
            is_nullable AS "Nullable",
            column_default AS "Default Value"

            FROM information_schema.columns
            WHERE table_schema = $1
            AND table_name = $2;
            """;

            var params = new ArrayList<Variant> ();
            params.add (new Variant.string (schema));
            params.add (new Variant.string (table_name));

            return yield exec_query_params (stmt, params);
        }

        public async Table db_table_indexes (string schema, string table_name) throws PsequelError {
            string stmt = """
            SELECT indexname, indexdef FROM pg_indexes
            WHERE schemaname = $1
            AND tablename = $2;
            """;

            var params = new ArrayList<Variant> ();
            params.add (new Variant.string (schema));
            params.add (new Variant.string (table_name));

            var raw_result = yield exec_query_params (stmt, params);
            

            return raw_result;
        }

        public async Table db_tablenames (string schema = "public") throws PsequelError {

            var builder = new StringBuilder ("select tablename from pg_tables where schemaname=");
            builder.append (@"\'$schema\';");

            string stmt = builder.free_and_steal ();
            var res = yield exec_query_internal (stmt);

            var table = new Table ((owned) res);

            return table;
        }

        public async string db_version () throws PsequelError {

            string stmt = "SELECT version ();";
            var table = yield exec_query (stmt);
            string version = table[0][0];

            return version;
        }

        public void connect_db (Connection conn) {
            string db_url = conn.url_form ();
            active_db = Postgres.connect_db (db_url);
        }

        public async void connect_db_async (Connection conn) throws PsequelError {
            string db_url = conn.url_form ();
            debug ("Connecting to %s", db_url);
            TimePerf.begin ();
            SourceFunc callback = connect_db_async.callback;
            try {
                var worker = new Worker ("connect database", () => {
                    active_db = Postgres.connect_db (db_url);

                    // Jump to yield
                    Idle.add ((owned) callback);
                });
                background.add (worker);

                yield;
                TimePerf.end ();
                check_connection_status ();
            } catch (ThreadError err) {
                debug (err.message);
                assert_not_reached ();
            }
        }

        public async Table exec_query (string query) throws PsequelError {
            var result = yield exec_query_internal (query);

            // check query status
            check_query_status (result);

            var table = new Table ((owned) result);

            return table;
        }

        public async Table exec_query_params (string query, ArrayList<Variant> params) throws PsequelError {
            var result = yield exec_query_params_internal (query, params);

            // check query status
            check_query_status (result);

            var table = new Table ((owned) result);

            return table;
        }

        private void check_connection_status () throws PsequelError {
            var status = active_db.get_status ();
            switch (status) {
            case Postgres.ConnectionStatus.OK:
                // Success
                break;
            case Postgres.ConnectionStatus.BAD:
                var err_msg = active_db.get_error_message ();
                throw new PsequelError.CONNECTION_ERROR (err_msg);
            default:
                debug ("Programming error: %s not handled", status.to_string ());
                assert_not_reached ();
            }
        }

        private void check_query_status (Result result) throws PsequelError {

            var status = result.get_status ();

            switch (status) {
            case ExecStatus.TUPLES_OK:
                // success
                break;
            case ExecStatus.FATAL_ERROR:
                var err_msg = result.get_error_message ();
                debug ("Fatal error: %s", err_msg);
                throw new PsequelError.QUERY_FAIL (err_msg.dup ());
            default:
                debug ("Programming error: %s not handled", status.to_string ());
                assert_not_reached ();
            }
        }

        private async Result exec_query_internal (string query) throws PsequelError {

            debug ("Exec: %s", query);
            TimePerf.begin ();

            // Boilerplate
            SourceFunc callback = exec_query_internal.callback;
            Result result = null;
            try {
                // Important line.
                var worker = new Worker ("exec query", () => {
                    // Important line.
                    result = active_db.exec (query);
                    Idle.add ((owned) callback);
                });

                background.add (worker);

                yield;
                TimePerf.end ();

                return (owned) result;
            } catch (ThreadError err) {
                debug (err.message);
                assert_not_reached ();
            }
        }

        private async Result exec_query_params_internal (string query, ArrayList<Variant> params) throws PsequelError {

            int n_params = params.size;
            string[] values = new string[n_params];

            for (int i = 0; i < n_params; i++) {
                if (params[i].is_of_type (VariantType.STRING)) {
                    values[i] = params[i].get_string ();
                } else if (params[i].get_type ().is_basic ()) {
                    values[i] = params[i].print (false);
                } else {
                    debug ("Programming error, got type '%s'", params[i].get_type_string ());
                    assert_not_reached ();
                }
            }

            debug ("Exec Param: %s", query);
            TimePerf.begin ();

            SourceFunc callback = exec_query_params_internal.callback;
            Result result = null;

            try {
                var worker = new Worker ("exec query params", () => {
                    result = active_db.exec_params (query, n_params, null, values, null, null, 0);
                    // Jump to yield
                    Idle.add ((owned) callback);
                });
                background.add (worker);

                yield;

                //  worker.get_result ();

                TimePerf.end ();

                return (owned) result;
            } catch (ThreadError err) {
                debug (err.message);
                assert_not_reached ();
            }

        }

        private Database active_db;
        private unowned ThreadPool<Worker> background;
    }
}