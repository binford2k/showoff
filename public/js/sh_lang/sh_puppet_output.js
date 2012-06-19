if (! this.sh_languages) {
  this.sh_languages = {};
}
sh_languages['puppet_output'] = [
  [
    [
      /^info:.*/g,
      'sh_info',
      -1
    ],
    [
      /^notice:.*/g,
      'sh_notice',
      -1
    ],
    [
      /^warning:.*/g,
      'sh_warning',
      -1
    ]
  ]
];
