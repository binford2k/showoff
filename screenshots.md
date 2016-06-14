---
layout: default
title: Screenshots
weight: 3
---

## {{ page.title }}

{% for screenshot in site.data.screenshots %}
  <div class="screenshot">
    <a href="{{site.baseurl}}/screenshots/{{ screenshot[0] }}" data-title="{{ screenshot[1].text }}" data-lightbox="screenshots">
      <img src="{{site.baseurl}}/screenshots/{{ screenshot[1].thumb }}" />
    </a>
    {% if screenshot[1].text %}
    <span class="description">{{ screenshot[1].text }}</span>
    {% endif %}
  </div>
{% endfor %}

<script src="https://ajax.googleapis.com/ajax/libs/jquery/2.2.4/jquery.min.js"></script>
<script src="{{site.baseurl}}/js/lightbox.min.js"></script>
<script>
    lightbox.option({
      'fadeDuration': 250,
      'resizeDuration': 250
    })
</script>
