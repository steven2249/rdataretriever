#' Install datasets via the Data Retriever.
#'
#' Data is stored in either CSV files or one of the following database management
#' systems: MySQL, PostgreSQL, SQLite, or Microsoft Access.
#'
#' @param dataset the name of the dataset that you wish to download
#' @param connection what type of database connection should be used. 
#' The options include: mysql, postgres, sqlite, msaccess, or csv'
#' @param db_file the name of the datbase file the dataset should be loaded 
#' into
#' @param conn_file the path to the .conn file that contains the connection
#' configuration options for mysql and postgres databases. This defaults to 
#' mysql.conn or postgres.conn respectively. The connection file is a file that
#' is formated in the following way:
#' \tabular{ll}{
#'   host     \tab my_server@my_host.com\cr
#'   port     \tab my_port_number       \cr
#'   user     \tab my_user_name         \cr
#'   password \tab my_password
#' }
#' @param data_dir the location where the dataset should be installed.
#' Only relevant for csv connection types. Defaults to current working directory
#' @param log_dir the location where the retriever log should be stored if
#' the progress is not printed to the console
#' @export
#' @examples
#' \donttest{
#' rdataretriever::install('iris', 'csv')
#' }
install = function(dataset, connection, db_file=NULL, conn_file=NULL,
                   data_dir='.', log_dir=NULL){ 
  if (missing(connection)) {
    stop("The argument 'connection' must be set to one of the following options: 'mysql', 'postgres', 'sqlite', 'msaccess', 'csv', 'json' or 'xml'")
  }
  else if (connection == 'mysql' | connection == 'postgres') {
    if (is.null(conn_file)) {
      conn_file = paste('./', connection, '.conn', sep='')
    }
    if (!file.exists(conn_file)) {
      format = '\n    host my_server@myhost.com\n    port my_port_number\n    user my_user_name\n    password my_pass_word'
      stop(paste("conn_file:", conn_file, "does not exist. To use a",
                  connection, "server create a 'conn_file' with the format:", 
                 format, "\nwhere order of arguments does not matter"))
    }
    conn = data.frame(t(utils::read.table(conn_file, row.names=1)))
    writeLines(strwrap(paste('Using conn_file:', conn_file,
                             'to connect to a', connection,
                             'server on host:', conn$host)))
    cmd = paste('retriever install', connection, dataset, '--user', conn$user,
                '--password', conn$password, '--host', conn$host, '--port',
                conn$port)
  }
  else if (connection == 'sqlite' | connection == 'msaccess') {
    if (is.null(db_file))
      cmd = paste('retriever install', connection, dataset)
    else
      cmd = paste('retriever install', connection, dataset, '--file', db_file)
  }
  else if (connection %in% c('csv', 'json', 'xml')) {
    cmd = paste('retriever install', connection, '--table_name',
                  file.path(data_dir, '{db}_{table}.csv'), dataset)
  }
  else
    stop("The argument 'connection' must be set to one of the following options: 'mysql', 'postgres', 'sqlite', 'msaccess', 'csv', 'json' or 'xml'")
  if (!is.null(log_dir)) {
    log_file = file.path(log_dir, paste(dataset, '_download.log', sep=''))
    cmd = paste(cmd, '>', log_file, '2>&1')
  }
  run_cli(cmd)
}

#' Fetch a dataset via the Data Retriever
#'
#' Each datafile in a given dataset is downloaded to a temporary directory and
#' then imported as a data.frame as a member of a named list.
#'
#' @param dataset the name of the dataset that you wish to download
#' @param quiet logical, if true retriever runs in quiet mode
#' @export
#' @examples
#' \donttest{
#' ## fetch the portal Database
#' portal = rdataretriever::fetch('portal')
#' class(portal)
#' names(portal)
#' ## preview the data in the portal species datafile
#' head(portal$species)
#' }
fetch = function(dataset, quiet=TRUE){
  temp_path = tempdir()
  if (quiet)
    run_cli(paste('retriever -q install csv --table_name',
                 file.path(temp_path, '{db}_{table}.csv'),
                 dataset))
  else
    install(dataset, connection='csv', data_dir=temp_path)
  files = dir(temp_path)
  dataset_underscores = gsub("-", "_", dataset) #retriever converts - in dataset name to _ in filename
  files = files[grep(dataset_underscores, files)]
  out = vector('list', length(files))
  list_names = sub('.csv', '', files)
  list_names = sub(paste(dataset, '_', sep=''), '', list_names)
  names(out) = list_names
  for (i in seq_along(files))
    out[[i]] = utils::read.csv(file.path(temp_path, files[i]))
  return(out)
}

#' Download datasets via the Data Retriever.
#'
#' Directly downloads data files with no processing, allowing downloading of
#' non-tabular data.
#'
#' @param dataset the name of the dataset that you wish to download
#' @param path the path where the data should be downloaded to
#' @param sub_dir if true and the downloaded dataset is stored in subdirectories those subdirectories will be preserved and placed according the path argument, defaults to false.
#' @param log_dir the location where the retriever log should be stored if
#' the progress is not printed to the console
#' @export
#' @examples 
#' \donttest{
#' rdataretriever::download('portal')
#' ## list files downloaded
#' dir('.', pattern='portal')
#' }
download = function(dataset, path='.', sub_dir=FALSE, log_dir=NULL) {
    if (sub_dir)
        cmd = paste('retriever download', dataset, '-p', path, '--subdir')
    else 
        cmd = paste('retriever download', dataset, '-p', path)
    if (!is.null(log_dir)) {
        log_file = file.path(log_dir, paste(dataset, '_download.log', sep=''))
        cmd = paste(cmd, '>', log_file, '2>&1')
    }
    run_cli(cmd)
}

#' Name all available dataset scripts.
#'
#' Additional information on the available datasets can be found at http://data-retriever.org/available-data.html
#' 
#' @return returns a character vector with the available datasets for download
#' @export
#' @examples 
#' \donttest{
#' rdataretriever::datasets()
#' }
datasets = function(){
  run_cli('retriever ls', intern = TRUE)
}

#' Reset rdataretriever.
#'
#' Reset the components of rdataretriever using scope [ all, scripts, data, connection]
#'
#' @param scope what components to reset. Options include: 'scripts', 'data', 
#' 'connection' and 'all', where 'all' is the default setting that 
#'  resets all components.
#' @export
#' @examples
#' \donttest{
#' rdataretriever::reset()
#' }
reset = function(scope='all') {
  os = Sys.info()[['sysname']]
  home_dir = Sys.getenv('HOME')
  print(paste("This will delete", toupper(scope), "cached infomation"))
  choice.name <- readline(prompt = "Do you want to proceed? (y/N)")
  if (tolower(scope) == "all" & tolower(choice.name) == "y") {
    if (file.exists(file.path(home_dir, ".retriever"))) {
      unlink(file.path(home_dir, ".retriever"), recursive = TRUE)
    }
  } else if (tolower(scope) == "scripts" &
             tolower(choice.name) == "y") {
    if (file.exists(file.path(home_dir, ".retriever", "scripts"))) {
      unlink(file.path(home_dir, ".retriever", "scripts"), recursive = TRUE)
    }
  }else if (tolower(scope) == "data" & tolower(choice.name) == "y") {
    if (file.exists(file.path(home_dir, ".retriever", "raw_data"))) {
      unlink(file.path(home_dir, ".retriever", "raw_data"), recursive = TRUE)
    }
  }else if (tolower(scope) == "connections" &
            tolower(choice.name) == "y") {
    if (file.exists(file.path(home_dir, ".retriever", "connections"))) {
      unlink(file.path(home_dir, ".retriever", "connections"), recursive = TRUE)
    }
  }
}

#' Update the retriever's dataset scripts to the most recent versions.
#' 
#' This function will check if the version of the retriever's scripts in your local
#' directory \file{~/.retriever/scripts/} is up-to-date with the most recent official
#' retriever release. Note it is possible that even more updated scripts exist
#' at the retriever repository \url{https://github.com/weecology/retriever/tree/master/scripts}
#' that have not yet been incorperated into an official release, and you should
#' consider checking that page if you have any concerns. 
#' @keywords utilities
#' @export
#' @examples
#' \donttest{
#' rdataretriever::get_updates()
#' }
get_updates = function() {
    writeLines(strwrap('Please wait while the retriever updates its scripts, ...'))
    update_log = run_cli('retriever update', intern=TRUE, ignore.stdout=FALSE,
                         ignore.stderr=TRUE)
    writeLines(strwrap(update_log[3]))
}

#' print the output from get_updates
#' @keywords internal
#' @export
print.update_log = function(x, ...) {
    if (length(x) == 0) {
        cat('No scripts downloaded')
    } 
    else {
        # clean up and print the update log output
        object = strsplit(paste(x, collapse = ' ; '), 'Downloading script: ')
        object = sort(sapply(strsplit(object[[1]][-1], ' ; '), 
                       function(x) x[[1]][1]))
        object[1] = paste('Downloaded scripts:', object[1])
        cat(object, fill=TRUE, sep=', ')
    }
}

.onAttach = function(...) {
    packageStartupMessage(
        "\n  Use get_updates() to download the most recent release of download scripts
     
    New to rdataretriever? Examples at
      https://github.com/ropensci/rdataretriever/
      Use citation(package='rdataretriever') for the package citation
    \nUse suppressPackageStartupMessages() to suppress these messages in the future")
}

.onLoad = function(...) {
    check_for_retriever()
}

#' Determine and set a consistent HOME across systems
#'
#' On Windows RStudio produces different results for Sys.getenv('HOME') than
#' running R in other ways. This also influences CLIs for other programs wrapped
#' in R.  This function checks to see if an extra "Documents" has been appended
#' to the home path and sets the environmental variable correctly.
#' @keywords internal
set_home = function(...) {
    Sys.setenv(HOME = gsub("/Documents", "", Sys.getenv('HOME')))
}

#' Check if retriever is on the user's path
#' @keywords internal
check_for_retriever = function(...) {
    retriever_path = Sys.which('retriever')
    set_home()
    home_dir = Sys.getenv('HOME')
    #Rstudio will not import any paths configured for anaconda python installs, so add default anaconda paths
    #manually. See http://stackoverflow.com/questions/31121645/rstudio-shows-a-different-path-variable
    if (retriever_path == '') {
        os = Sys.info()[['sysname']]
        possible_pathes = c('/Anaconda3/Scripts',
                            '/Anaconda2/Scripts',
                            '/Anaconda/Scripts',
                            '/Miniconda3/Scripts',
                            '/Miniconda2/Scripts',
                            '/anaconda3/bin',
                            '/anaconda2/bin',
                            '/anaconda/bin',
                            '/miniconda3/bin',
                            '/miniconda2/bin')
        for (i in possible_pathes) {
            Sys.setenv(PATH = paste(Sys.getenv('PATH'), ':', home_dir, i, sep = ''))
        }
    }

    retriever_path = Sys.which('retriever')
    
    if (retriever_path == '') {
        path_warn = 'The retriever is not on your path and may not be installed.'
        mac_instr = 'Follow the instructions for installing and manually adding the Data Retriever to your path at http://data-retriever.org/download.html'
        download_instr = 'Please upgrade to the most recent version of the Data Retriever, which will automatically add itself to the path http://data-retriever.org/download.html'
        os = Sys.info()[['sysname']]
        if (os == 'Darwin')
            packageStartupMessage(paste(path_warn, mac_instr))
        else 
            packageStartupMessage(paste(path_warn, download_instr))
    }    
}

#' Run command using command line interface
#'
#' system() calls to the retriever execute inconsistently on Windows so this
#' function uses shell() on Windows and system() on other operating systems
#'
#' @param command string containing a command line call to the retriever
#' @keywords internal
run_cli = function(...) {
    os = Sys.info()[['sysname']]
    if (os == "Windows") {
        shell(...)
    } else {
        system(...)
    }
}
