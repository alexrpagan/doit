var rPath = /^\/doit\/\w+\//;
var basePath = rPath.exec(location.pathname).toString();

/* layout */
var topPane = $('.pane.top'),
    leftPane = $('.pane.left'),
    rightPane = $('.pane.right');

function setPaneHeights () {
    var rightExtraHeight = $(rightPane).outerHeight(true) - $(rightPane).height(),
        leftExtraHeight = $(leftPane).outerHeight(true) - $(leftPane).height();
    $(rightPane).height($(window).height() - $(topPane).outerHeight(true) - rightExtraHeight);
    $(leftPane).height($(rightPane).height() - leftExtraHeight);
}

function setMapperDimensions () {
    var $mapper = $('.mapper'),
        mapperMargin = $mapper.outerWidth(true) - $mapper.outerWidth(false)
        scrollBarWidth = 16; // Just an approx.
    $mapper.width(rightPane.innerWidth() - mapperMargin - scrollBarWidth);
}

$(window).resize(setPaneHeights);
$(window).resize(setMapperDimensions);
$(window).resize();

/* match menu lists  */
var matchers = $('.mapper td.match');

$(matchers).each(function () {
    var openButton = $('.button', this);
    var list = $('.map-list', this);
    $(openButton).click(function (e) {
        if ($(openButton).is('.disabled'))
            return;
 	e.stopPropagation();
	toggle_match_list(list);
    });
});

function get_match_list(mlist, field_id, afterLoad) {
    afterLoad = (typeof afterLoad === 'function') ? afterLoad : function () {};
    var url = basePath + 'fields/' + field_id + '/candidates/',
        data = {},
        callback = function (responseText) {
            $(mlist).html(responseText);
            init_match_list(mlist);
            afterLoad();
        };
    $(mlist).html('<p>Loading...</p>');
    $.get(url, data, callback);
}

function init_match_list(mlist) {
    var container = $(mlist).closest('.map-list-container');
    var pos = $(container).prev().offset();
    if (pos.top - 32 + $(container).outerHeight() > $(window).height())
        $(container).css('top', $(window).height() - 280);

    $('.candidate', mlist).click(function () {
        $('.selected').removeClass('selected');
        $(this).addClass('selected');
        update_mapping_choice(mlist);
        close_match_list(mlist);
    });
}

function open_match_list (mlist) {
    //$(mlist).closest('tr').find('.button').addClass('disabled');
    if ($('.map-list-container.open').length)
        return;
    var container = $(mlist).closest('.map-list-container');
    var pos = $(container).prev().offset();
    $(container)
        .addClass('open')
        .css('top', pos.top - 32)
        .css('left', pos.left + 16);

    $(container).click(function (e) {e.stopPropagation();});
    $('body')
	.click( function () {
	    close_match_list(mlist);
	});
}

function close_match_list (mlist) {
    $(mlist).closest('.map-list-container')
        .removeClass('open')
        .css('top', 'auto')
        .css('left', 'auto')
        .closest('tr')
            .find('.button')
                .removeClass('disabled');
}

function toggle_match_list (mlist) {
    if (!$(mlist).children().length) {
        var field_id = $(mlist).closest('td').find('.choice')
                           .attr('id').split('-is-')[0];
        get_match_list(mlist, field_id);
    }
    if ($(mlist).closest('.map-list-container').is('.open'))
	close_match_list(mlist);
    else
	open_match_list(mlist);
}

function update_mapping_choice (mlist) {
    var choice = $('.selected', mlist);
    var mapping = $(choice).attr('id').split('-to-');
    var fromId = mapping[0];
    var toId = mapping[1];
    var name = $(choice).text();
    var borderColor = $(choice).css('border-left-color');
    var title = $(choice).attr('title');
    var target = $(choice).closest('td').find('.choice');
    $(target)
        .text(name)
        .css('border-left-color', borderColor)
        .attr('id', fromId + '-is-' + toId)
        .attr('data-original-title', title)
        .attr('title', title);
    update_score_tooltips();
}

/* match list filters */
$('.map-list-container')
    .find('.filter')
    .children()
    .focus(function () {
        if ($(this).val() === 'Filter')
            $(this).val('');
    })
    .blur(function () {
        if ($(this).val() === '')
            $(this).val('Filter');
    })
    .keyup(function () {
        update_filter(this);
    });

function update_filter (inputEl) {
    var patterns = $(inputEl).val().toLowerCase().split(' ');
    var listElems = $(inputEl).closest('.map-list-container').find('.candidate');
    if (!patterns.length)
        $(listElems).show();
    else
        $(listElems)
            .hide()
            .filter(function () {
                for (var i=0; i<patterns.length; i++)
                    if ($(this).text().toLowerCase().indexOf(patterns[i]) === -1)
                        return false;
                return true;
            })
            .show();
}

/* match list "suggest new..." buttons */
var $suggButtons = $('.map-list-container .suggest');

$suggButtons.click(function () {
   var $this = $(this),
       $row = $this.closest('.mapper-row'),
       fid = $row.attr('id').substr(3),
       fname = $row.find('.attr').text(),
       url = basePath + 'suggest-new-attribute/form?fid=' + fid + '&fname=' + fname,
       width = 600,
       callback = function () {
           var $suggestForm = $('.popover form');
           $suggestForm.submit(function (e) {
               e.preventDefault();
               var url = basePath + 'suggest-new-attribute/',
                   data = $suggestForm.serialize(),
                   callback = function () {
                       alert('Ok!');
                       close_popover();
                   };
               $.post(url, data, callback);
           });
       };
   fill_popover(url, width, callback); 
});

/* action buttons */
var actions = $('.actions');
var accept_buttons = $('.accept', actions);
var reject_buttons = $('.reject', actions);
var reset_buttons  = $('.reset',  actions);
var viewsource_buttons = $('.viewsource');

$(accept_buttons).each( function () {
    var container = $(this).parent().closest('tr');
    $(this).click( function () {
	container.find('.status').addClass('dirty');
	update_save_button();
	reset_and_display_slider(container.next());
	$(container)			// This attribute's row (tr)
	    .addClass('mapped')
            .removeClass('unmapped')
            .find('.match')		// The td with the match list
                .find('.button')	// The match list open button
                    .addClass('disabled')
                .end()
	        .find('.choice')	// The chosen match list item
	           .addClass('new-mapping')
	        .end()
	    .end()
	    .find('.status')	// The attributes status cell
	        .text('mapped')
	    .end();
    });
});

$(reject_buttons).each(function () {
    var $this = $(this),
        $container = $this.parent().closest('tr'),
	$mlist = $container.find('.map-list'),
        currentMapping = $container.find('.choice').attr('id'),
        fieldId = currentMapping.substr(0, currentMapping.indexOf('-'));
    $this.click( function () {
	$container.find('.status').addClass('dirty');
	update_save_button();
	reset_and_display_slider($container.next());
        function selectNextChoice () {
	    $('.selected', $mlist)
                .removeClass('selected')
                .addClass('rejected')
                .next()
                    .addClass('selected');
            if (!$('.selected', $mlist).length)
                $('.candidate', $mlist).first().addClass('selected');
            update_mapping_choice($mlist);
        }
        if (!$mlist.find('.candidate').length)
            get_match_list($mlist, fieldId, selectNextChoice);
        else
            selectNextChoice();
    });
});

$(reset_buttons).each( function () {
    var $container = $(this).parent().closest('tr');
    if ($container.find('.choice.mapping').length)
        return;
    $(this).click( function () {
	$container.next().hide();
	$container
            .removeClass('mapped')
            .addClass('unmapped')
            .find('.match')
                .find('.button')
                    .removeClass('disabled')
                .end()
	        .find('.choice')
	            .removeClass('new-mapping')
                    .removeClass('mapping')
	        .end()
                //.find('.rejected')
                //    .removeClass('rejected')
                //.end()
	    .end()
	    .find('.status')
                .removeClass('dirty')
	        .text('unmapped')
	    .end();
	update_save_button();
    });
});

function load_source(sourceId){
    var $window = $('.pane.right'),
    table = $('.viewTable');
    fetch_data_table(sourceId, function(data) {
	table.replaceWith(data);
	fetch_source_meta(sourceId, function(data) {
	    $('.source-meta').replaceWith(data);
	});
	toggle_panel();
    });
}

function questions_are_visible(){
    return !$('.mapper', $('.pane.right')).is(':hidden');
}

function toggle_panel(){
    var window = $('.pane.right'),
    mapper = $('.mapper', window),
    table = $('.viewTable', window),
    toggle_display = $('.toggle-data-panel').each(function(){$(this).show()});
    meta = $('.pane.left');
    curr_source = $('.current-source');

    if (questions_are_visible()) {
	curr_source.show();
	meta.show();
	mapper.hide();
	table.show();
	toggle_display.each(function(){$(this).addClass('btn-primary')});
	toggle_display.text('Back to questions...');
    } else {
	curr_source.hide();
	meta.hide();
	table.hide();
	mapper.show();
	toggle_display.each(function(){$(this).removeClass('btn-primary')});
	toggle_display.text('See Loaded Source');
    }
}

function fetch_data_table (sourceId, callback) {
    var rPath = /^\/doit\/\w+\//;
    var basePath = rPath.exec(location.pathname).toString();
    var url = basePath + 'sources/' + sourceId + '/table';
    $.get(url, {}, callback);
}

function fetch_source_meta (sourceId, callback) {
    var rPath = /^\/doit\/\w+\//;
    var basePath = rPath.exec(location.pathname).toString();
    var url = basePath + 'sources/' + sourceId + '/meta';
    $.get(url, {}, callback);
}

$(viewsource_buttons).each(function() {
    var source_id = $(this).data('source-id');
    var source_name = $(this).data('source-name');
    $(this).click( function () {
	load_source(source_id);
	$('.current-source').text(source_name);
    });
});

$('.toggle-data-panel').each(
    function(){
	$(this).click(function(){
	    toggle_panel();
	});
    });

/* control panel */
var $saveButton = $('.control.save', topPane),
    $resetButton = $('.control.reset', topPane),
    $mapallButton = $('.control.mapall', topPane),
    $viewTableButton = $('.control.viewTable-button', topPane),
    $backButton = $('.control.back', topPane),
    $helpButton = $('.control.help-btn', topPane);

$resetButton.click(function () {
    $(reset_buttons).click();
});

$mapallButton.click(function () {
    $(accept_buttons).click();
});

$saveButton.click(function () {
    var answerer_id = 0,
        mappings = [],
        rejected = [];

    $('.new-mapping', matchers).each(function () {
	mappings.push($(this).attr('id').split('-is-'));
    });
    $('.rejected', matchers).each(function () {
	rejected.push($(this).attr('id').split('-to-'));
    });

    answerer_id = $('input#answerer_id').val();

    save_anyway = confirm("After you save your answers, there is no way to alter them. Are you sure that you want to save?");

    if (save_anyway && mappings.length + rejected.length) {
        var url = basePath + 'save',
            data = 'mappings=' + JSON.stringify(mappings) +
                   '&rejects=' + JSON.stringify(rejected) +
	           '&answerer_id=' + answerer_id,

            callback = function (d) {
		$('.confidence').hide();

		$('.new-mapping')
		    .closest('.mapper-row')
		    .addClass('hide')

		$('.rejected')
		    .closest('.mapper-row')
		    .addClass('hide')

                $('.new-mapping')
                    .removeClass('new-mapping')
                    .addClass('mapping')
                    .removeAttr('style');

                $('.rejected').removeClass('rejected');

		$('.dirty').each(function() {
		    $(this).removeClass('dirty').addClass('committed');
		});

		update_save_button();

		if($('.mapper-row').length == $('.mapper-row.hide').length){
		    alert('Loading x more questions...');
		}
            };
        $.post(url, data, callback);
    }
});

$backButton.click(function() {
    var url = $('#backlink').attr('href');
    // if unsaved changes, create popup asking really?
    if (page_has_unsaved_content()){
	var really_leave = confirm("You have unsaved work. Do you want to abandon your changes?");
	if (really_leave) {
	    window.location = url;
	}
    } else {
	window.location = url;
    }
});

/* help */

function init_help() {
    var seen_help = $.cookie('seen_help');
    if (!seen_help) {
	$('.help').show();
    }
}

function toggle_help() {
    var seen_help = $.cookie('seen_help');
    if (!seen_help && !$('.help').is(':hidden')) {
	$.cookie('seen_help', true);
    }
    $('.help').toggle();
};

$helpButton.click(function() {
    toggle_help();
});

$('.help').click(function(){toggle_help()})

/* detailed views */
var detail_buttons = $('.detail', actions);

$(detail_buttons).each( function () {
//    var attr_name = encodeURIComponent($(this).closest('tr').children().first().text());
    var fid = $(this).closest('tr').attr('id').slice(3);
    $(this).click( function () {
	fill_popover(basePath + 'fields/' + fid + '/summary', 600);
    });
});

function open_popover (width) {
    $('#detailModal').modal('show');
}

function close_popover (){
    $('#detailModal').modal('hide');
}

function fill_popover (url, width, callback) {
    //close_popover();
    width = width || 600;
    callback = typeof callback === 'function' ? callback : function () {};
    var pop = $(open_popover(width));

    $("#modal-contents").html('<p>Loading...</p>');
    $.get(url, function (d) {
	$("#modal-contents").html(d);
        callback();
    });

    return $(pop);
}

/* tooltips */

function update_score_tooltips () {
    $('.tooltip-container.score').tooltip({selector:'div[rel=tooltip]', placement:'left'});
}

function init_static_tooltips () {
    $('.tooltip-container.example').tooltip({
	selector:'span[rel=tooltip]', 
	delay: {show: 250, hide:100 },
	placement:'bottom'});

    $('.tooltip-container.viewsource-btn-box').tooltip({
	selector:'span[rel=tooltip]', 
	delay: {show: 250, hide:100 },
	placement:'right'});
}

/*confidence sliders*/

function reset_and_display_slider($container) {
    // expects the tr containing the confidence slider
    $slider = $container.find('.confidence-slider');
    $slider.slider("value", 0);
    // show the slider container
    $container.show();
}

function init_sliders() {
    var init_value = 0;
    $(".confidence-slider").slider({
        range: "min",
        value: init_value,
        min: 50,
        max: 100,
        slide: function( event, ui ) {
            $(event.target).data('confidence', ui.value)
        }
    });
    $(".confidence-slider").data('confidence', init_value); 
    $(".confidence-slider").each( function (i) {
	var slider = this;
	var done_btn = $(this).parent().next().children('.done-with-confidence')[0];
	var $container = $(this).closest('.confidence');
	$(done_btn).click(function(){
	    $container.hide();
	});
    });
}


/* save button status */

function page_has_unsaved_content() {
    return $('.dirty').length != 0;
}

function update_save_button() {
    var indic_class = 'btn-primary';
    if(page_has_unsaved_content()){
	$saveButton.addClass(indic_class);
    } else {
	$saveButton.removeClass(indic_class);
    }
}

function init_page() {
    init_help();
    update_score_tooltips();
    init_static_tooltips();
    init_sliders();
}

$(function() {
    init_page();
});
