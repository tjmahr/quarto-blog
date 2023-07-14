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
- yaml `title` -> yaml `title`
- yaml `excerpt` -> yaml `description`
- yaml `tags` -> yaml `categories`
- date in slug -> yaml `date`
- ??? preview image ???
- ??? header image stuff ???
- ??? un-jekyllify contents ???


❌ Putting my author name in `_quarto.yml` set it as a default on all posts. Don't need worry about that.

No! Put it in `_posts/_metadata.yml`. Otherwise it appears on the main page!

Where to set my `opts_chunk()` defaults? https://quarto.org/docs/computations/r.html#knitr-options says where.



