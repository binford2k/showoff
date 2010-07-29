!SLIDE subsection
# Custom events #

!SLIDE custom_and_unique_class
# 1st Example h1
<script>
// bind to custom event
$(".custom_and_unique_class").bind("showoff:show", function (event) {
  // animate the h1
  var h1 = $(event.target).find("h1");
  h1.delay(500)
    .slideUp(300, function () { $(this).css({textDecoration: "line-through"}); })
    .slideDown(300);
});
</script>

!SLIDE prevent_default
# 2nd Example h1
<script>
$(".prevent_default").bind("showoff:next", function (event) {
  var h1 = $(event.target).find("h1");
  if (h1.css("text-decoration") === "none") {
    event.preventDefault();
    h1.css({textDecoration: "line-through"})
  }
});
</script>

!SLIDE
# Switched
