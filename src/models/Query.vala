namespace Psequel {
    public class Query : Object, Json.Serializable {

        //  Properties must be public, get, set inorder to Json.Serializable works
        public string sql { get; set; }
        public string[] params {get; set;}

        public static Regex DDL_REG = /^(CREATE|DROP|RENAME|ALTER|INSERT|UPDATE|DELETE).*$/i;

        public Query (string sql) {
            base();
            this.sql = sql;
        }

        public Query.with_params (string sql, string[] params) {
            this(sql);
            this.params = params;
        }

        public void set_limit (int limit) {
            if (!is_dql ()) {
                return;
            }
            sql += @" LIMIT $limit";
        }

        public bool is_dql () {
            return sql.up (6) == "SELECT";
        }

        public bool is_ddl () {
            return DDL_REG.match (sql, 0, null);
        }

        public Query clone () {
            return (Query)Json.gobject_deserialize (typeof (Query), Json.gobject_serialize (this));
        }
    }
}