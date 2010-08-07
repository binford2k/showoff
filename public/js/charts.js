// Extension to jQuery that provides a method for "stitching together" two arrays.
jQuery.pairUp = function(left, right) {
  return left.map(function(value, index) {
    return [ value, right[index] ];
  });
};

// Extension to make extending the behaviour of an existing function slightly easier.
jQuery.methodChain = function(original, callback) { return callback(original); };

// Here are all of the various chart handlers that are supported.
var chartHandlers = {
  // This is a helper function that will extract the values from a 'table' element, 
  // generating a list of labels and a number of series.  It then yields the labels and
  // series back to the callback.
  //
  // Note that each series can have its own set of labels so, in both cases, you are
  // getting an array of arrays.  Blank cells, both for labels and values, are ignored.
  extractSeries: function(table, callback) {
    var series = [], labels = [];

    // The first row is either just another point in the series, or it is naming the
    // series.  If it's the latter then we will have 1 less naming cell than cells in
    // the following row.  Hopefully!
    seriesSelector         = 'tr';
    namingCellsInFirstRow  = $('tr:first-child td em', table);
    namingCellsInSecondRow = $('tr:nth-child(2) td em', table);
    if (namingCellsInFirstRow.length != namingCellsInSecondRow.length) {
      namingCellsInFirstRow.each(function() {
        series.push({ 
          name: $(this).text(),
          data: []
        });
      });
      seriesSelector = 'tr:first-child ~ tr';
    }

    // Now we can process the series data from the table
    $(seriesSelector, table).each(function() {
      $('td:not(:has(em))', this).each(function(index, cell) {
        values = (series[index] = series[index] || { data: [] });
        values.data.push(parseInt($(cell).text(), 10) || null);
      });
      $('td em', this).each(function() {
        labels.push($(this).text());
      });
    });

    callback(labels, series);
  },

  general: function(chart, table, callback) {
    var labels, series;
    this.extractSeries(table, function(l,v) { labels = l, series = v; });

    new Highcharts.Chart(callback({
      chart: {
        defaultSeriesType: 'bar',
        renderTo: chart[0]
      },
      title: { text: null },
      series: series,
      xAxis: { categories: labels },
      tooltip: {
        formatter: function() {
          return "<em>" + this.series.name + "</em><br/>" + this.x + ": " + this.y;
        }
      }
    }));
  },

  // Generates a pie chart.
  pie: function(chart, table, options) {
    this.general(chart, table, function(options) {
      options.chart.defaultSeriesType = 'pie';

      // This is such a hack! Basically take the general chart setup and rework the
      // series data so that the xAxis categories are included in the data.
      return $.extend(options, {
        series: options.series.map(function(series) {
          series.data = $.pairUp(options.xAxis.categories, series.data);
          return series;
        }),
        tooltip: {
          formatter: function() {
            return "<em>" + this.series.name + "</em><br/>" + this.percentage.toFixed(2) + "% (" + this.y + ")";
          }
        }
      });
    });
  },

  // Generates a barchart, both single and multi-series versions.
  bar: function(chart, table, options) {
    this.general(chart, table, function(options) {
      options.chart.defaultSeriesType = 'bar';
      return $.extend(options, {
        plotOptions: {
          bar: {
          }
        }
      });
    });
  },

  // Generates a stacked barchart.
  stacked: function(chart, table, options) {
    this.general(chart, table, function(options) {
      options.chart.defaultSeriesType = 'bar';
      return $.extend(options, {
        plotOptions: {
          series: { stacking: 'normal' },
          bar: {
          }
        },
        tooltip: {
          formatter: $.methodChain(options.tooltip.formatter, function(original) {
            return function() {
              return $.proxy(original, this)() + " (" + this.percentage.toFixed(2) + "%)";
            };
          })
        }
      });
    });
  },

  // Generates a line chart.
  line: function(chart, table, options) {
    this.general(chart, table, function(options) {
      options.chart.defaultSeriesType = 'line';
      return $.extend(options, {
        plotOptions: {
          line: {
          }
        }
      });
    });
  },

  // Generates an area chart.
  area: function(chart, table, options) {
    this.general(chart, table, function(options) {
      options.chart.defaultSeriesType = 'area';
      return $.extend(options, {
        plotOptions: {
          area: {
          }
        }
      });
    });
  }
};
