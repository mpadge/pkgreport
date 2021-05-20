
#' Generate report on package compliance with rOpenSci Statistical Software
#' requirements
#'
#' @param path Path to local repository
#' @return A `pkgcheck` object detailing all package assessments automatically
#' applied to packages submitted for peer review.
#' @export
pkgcheck <- function (path) {

    u <- url_from_desc (path)

    s <- suppressWarnings (pkgstats::pkgstats (path))
    s$path <- path
    pkgstats <- pkgstats_checks (s)

    out <- list ()
    out$package <- s$desc$package
    out$version <- s$desc$version
    out$url <- u
    out$license <- s$desc$license

    num_exported_fns <- pkgstats$value [pkgstats$measure == "n_fns_r_exported"]
    num_non_exported_fns <- pkgstats$value [pkgstats$measure ==
                                            "n_fns_r_not_exported"]
    num_src_fns <- sum (pkgstats$value [pkgstats$measure %in%
                        c ("n_fns_src", "n_fns_inst")])
    loc_exported_fns <- pkgstats$value [pkgstats$measure ==
                                        "loc_per_fn_r_exp"]
    loc_non_exported_fns <- pkgstats$value [pkgstats$measure ==
                                            "loc_per_fn_r_not_exp"]
    loc_src_fns <- stats::median (pkgstats$value [pkgstats$measure %in%
                                  c ("loc_per_fn_src", "loc_per_fn_inst")])
    num_params_per_fn <- pkgstats$value [pkgstats$measure ==
                                         "num_params_per_fn"]

    out$summary <- list (
         num_authors = s$desc$aut,
         num_vignettes = unname (s$vignettes [1]),
         num_data = unname (s$data_stats [1]),
         imported_pkgs = length (strsplit (s$desc$imports, ",") [[1]]),
         num_exported_fns = as.integer (num_exported_fns),
         num_non_exported_fns = as.integer (num_non_exported_fns),
         num_src_fns = as.integer (num_src_fns),
         loc_exported_fns = as.integer (loc_exported_fns),
         loc_non_exported_fns = as.integer (loc_non_exported_fns),
         loc_src_fns = as.integer (loc_src_fns),
         num_params_per_fn = as.integer (num_params_per_fn),
         languages = attr (pkgstats, "language"))

    repo <- utils::tail (strsplit (u, "/") [[1]], 1)
    org <- utils::tail (strsplit (u, "/") [[1]], 2) [1]
    commit <- get_latest_commit (org, repo)

    gitlog <- gert::git_log (repo = path, max = 1e6)
    # use email addresses to identify unique authors
    auts <- gsub ("^.*<|>$", "", unique (gitlog$author))

    out$git <- list (HEAD = commit$oid,
                     branch = get_default_branch (org, repo),
                     num_commits = nrow (gitlog),
                     since = min (gitlog$time),
                     num_authors = length (unique (auts)))

    out$srr <- pkgchk_srr_report (path)

    out$file_list <- list ()
    out$file_list$uses_roxy <- pkg_uses_roxygen2 (path)
    has_contrib <- unname (pkg_has_contrib_md (path))
    out$file_list$has_lifecycle <- has_contrib [2]
    out$file_list$has_contrib <- has_contrib [1]

    out$fns_have_exs <- all_pkg_fns_have_exs (path)
    index <- which (!grepl ("\\-package\\.Rd$", names (out$fns_have_exs)))
    out$fns_have_exs <- out$fns_have_exs [index]

    la <- left_assign (path) # tallies of "<-", "<<-", "="
    out$left_assigns <- list (global = la [["<<-"]] > 0)
    la <- la [names (la) != "<<-"]
    out$left_assigns$usage <- la

    out$file_list$has_url <- !is.na (s$desc$urls)
    out$file_list$has_bugs <- !is.na (s$desc$bugs)

    out$pkgstats <- pkgstats

    # ------------------------------------------------------------
    # -----------------   FUNCTION CALL NETWORK   ----------------
    # ------------------------------------------------------------

    visjs_dir <- file.path (getOption ("pkgcheck.cache_dir"),
                             "static")
    if (!dir.exists (visjs_dir))
        dir.create (visjs_dir, recursive = TRUE)

    visjs_file <- paste0 (repo,
                          "_pkgstats",
                          substring (commit$oid, 1, 8),
                          ".html")
    visjs_path <- file.path (visjs_dir, visjs_file)

    # clean up any older ones
    flist <- list.files (visjs_dir,
                         pattern = paste0 (repo, "_pkgstats"),
                         full.names = TRUE)

    if (!visjs_path %in% flist) {

        unlink (flist, recursive = TRUE)
        pkgstats::plot_network (s, vis_save = visjs_path)
    }

    out$network_file <- visjs_path


    # ------------------------------------------------------------
    # -----------------   BADGES + OTHER STUFF   -----------------
    # ------------------------------------------------------------

    out$badges <- ci_badges (u)
    if (!is.null (out$badges)) {
        if (any (grepl ("github", out$badges))) {
            out$github_workflows <- ci_results_gh (path)
        }
    }

    out$gp <- get_gp_report (path)

    class (out) <- c ("pkgcheck", class (out))

    return (out)
}

#' Format \pkg{pkgstats} data
#' @param s Output of \pkg{pkgstats} call.
#' @return Report as formatted string
#' @noRd
pkgstats_checks <- function (s) {

    s_summ <- pkgstats::pkgstats_summary (s)
    attr (s_summ, "path") <- s$path
    stat_chks <- stats_checks (s_summ)
    languages <- attr (stat_chks, "language")
    # ignore large numbers of files:
    stat_chks$noteworthy [grepl ("^files\\_", stat_chks$measure) &
                          stat_chks$percentile > 0.5] <- FALSE
    #is_noteworthy <- any (stat_chks$noteworthy)
    stat_chks$percentile <- 100 * stat_chks$percentile
    stat_chks$noteworthy [which (!stat_chks$noteworthy)] <- ""

    attr (stat_chks, "language") <- languages

    return (stat_chks)
}