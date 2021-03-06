# nocov start
.onLoad <- function (libname, pkgname) { # nolint

    cache_dir <- Sys.getenv ("PKGCHECK_CACHE_DIR")

    if (cache_dir == "") {
        cache_dir <- file.path (rappdirs::user_cache_dir (), "pkgcheck")
    }

    if (!dir.exists (cache_dir)) {
        dir.create (cache_dir, recursive = TRUE)
    }
    cache_dir <- normalizePath (cache_dir)
    Sys.setenv ("PKGCHECK_CACHE_DIR" = cache_dir)

    if (!dir.exists (file.path (cache_dir, "static"))) {
        dir.create (file.path (cache_dir, "static"), recursive = TRUE)
    }

    op <- options ()

    op.pkgcheck <- list (pkgcheck.cache_dir = cache_dir) # nolint

    toset <- !(names (op.pkgcheck) %in% names (op))
    if (any (toset))
        options (op.pkgcheck [toset])
    invisible ()
}
# nocov end
