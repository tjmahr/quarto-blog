# quarto-blog

Old Jekyll posts are named with 

`tjmahr.github.io/_R/2015-10-06-confusion-matrix-late-talkers.Rmd`

and yield 

`https://www.tjmahr.com/confusion-matrix-late-talkers/index.html`

having yaml fields like

```
title: Ordering constraints in brms using contrast coding
excerpt: But mostly how contrast matrices are computed
tags: 
  - r
  - bayesian
  - brms
  - math
header:
  overlay_image: "assets/images/2023-07-ruins-1280.jpg"
  image_description: "An ancient ruin"
  overlay_filter: rgba(10, 10, 10, 0.2)
  caption: "Photo credit: [**Russ McCabe**](https://unsplash.com/photos/4f_fhoAn3bI)"
```

Here, posts are named 

`quarto-blog/posts/confusion-matrix-late-talkers/index.qmd`

and yield

`quarto-blog/_site/posts/confusion-matrix-late-talkers/index.html`

having yaml fields like

```
title: "Confusion matrix statistics on late talker diagnoses"
description: "Posterior predictive values and the like."
author: "TJ Mahr"
date: "2015-10-06"
categories: 
  - r
  - caret
# preview image
image: "image.jpg"
```

So to migrate a post, I need to map:

- path `[date]-[slug-name].Rmd` -> path `posts/[slug-name]/index.qmd`
- yaml `excerpt` -> yaml `description`
- yaml `tags` -> yaml `categories`
- date in slug -> yaml `date`
- ??? preview image ???
- ??? header image stuff ???
- ??? un-jekyllify contents ???


❌ Putting my author name in `_quarto.yml` set it as a default on all posts. Don't need worry about that.

No! Put it in `_posts/_metadata.yml`. Otherwise it appears on the main page!

Where to set my `opts_chunk()` defaults? https://quarto.org/docs/computations/r.html#knitr-options says where.

I had to set `output-dir: docs` in the `_quarto.yml` file to make it play nice with GitHub.

### _footer.Rmd

On my Jekyll, I had a file `_footer.Rmd` that was included in every document that did three things.

1. Say when it was last knitted.
2. Link to the source on GitHub.
3. Include the Session Info.

I can recreate some of this by using Quarto's features.

I get (1) by putting:

```
date-modified: "`r format(Sys.Date())`" 
```

in a post's yaml header.

I get the (2) by adding this to  `_posts/_metadata.yml` 

```
code-tools:
  source: repo
```

and setting 

```
website:
  repo-url: "https://github.com/tjmahr/quarto-blog"
```

includes the link in the post.


