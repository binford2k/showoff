if (! this.sh_languages) {
  this.sh_languages = {};
}
sh_languages['puppet_output'] = [
  [
    [
      /^[iI]nfo:.*/g,
      'sh_info',
      -1
    ],
    [
      /^[nN]otice:.*/g,
      'sh_notice',
      -1
    ],
    [
      /^[wW]arning:.*/g,
      'sh_warning',
      -1
    ]
  ]
];
