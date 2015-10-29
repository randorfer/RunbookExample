// Define some variables for root relative
define('WP_HOME', 'http://' . $_SERVER['HTTP_HOST']);
define('WP_SITEURL', 'http://' . $_SERVER['HTTP_HOST']);


// ** MySQL settings - You can get this info from your web host ** //

/** Grab the connection string out of ENV */
$conn = getenv("MYSQLCONNSTR_DefaultConnection");
function connStrToArray($connStr){
	$connArray = array();
	$stringParts = explode(";", $connStr);
	foreach($stringParts as $part){
		$temp = explode("=", $part);
		$connArray[$temp[0]] = $temp[1];
	}
	return $connArray;
}

$dbConn = connStrToArray($conn);

/** The name of the database for WordPress */
define('DB_NAME', $dbConn["Database"]);

/** MySQL database username */
define('DB_USER', $dbConn["User Id"]);

/** MySQL database password */
define('DB_PASSWORD', $dbConn["Password"]);

/** MySQL hostname */
define('DB_HOST', $dbConn["Data Source"]);

/** Database Charset to use in creating database tables. */
define('DB_CHARSET', 'utf8');

/** The Database Collate type. Don't change this if in doubt. */
define('DB_COLLATE', '');