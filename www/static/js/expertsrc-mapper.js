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





/* action buttons */
var actions = $('.actions');
var accept_buttons = $('.accept', actions);
var reject_buttons = $('.reject', actions);
var reset_buttons  = $('.reset',  actions);
var dropdown_buttons = $('.drop');

var viewsource_buttons = $('.viewsource');

$(accept_buttons).each( function () {
    var $container = $(this).parent().closest('tr');
    var $mlist = $container.find('.map-list');
    $(this).click( function () {
	$container.find('.status').addClass('dirty');
	update_save_button();
	$container			// This attribute's row (tr)
	    .addClass('mapped')
            .removeClass('unmapped')
            .find('.match')		// The td with the match list
                .find('.button')	// The match list open button
                    .addClass('disabled')
                .end()
	        .find('.choice')	// The chosen match list item
	           .removeClass('rejected')
	           .addClass('new-mapping')
                .end()
	    .end()
	    .find('.status')	// The attributes status cell
	        .text('mapped')
	    .end();
	reset_and_display_slider($container.next(), $container.find('.new-mapping'));
    });
});


$(reject_buttons).each(function () {

    var $this = $(this),
        $container = $this.parent().closest('tr'),
	$mlist = $container.find('.map-list'),
        currentMapping = $container.find('.choice').attr('id'),
        fieldId = currentMapping.substr(0, currentMapping.indexOf('-'));

    $this.click( function () {
	// change state of the row.
	$container
	    .removeClass('unmapped')
	    .removeClass('mapped')
	    .addClass('antimapped');

	if(!$mlist.find('.candidate').length)
	    fetch_match_list($mlist, fieldId, function () {
		if (!$('.selected', $mlist).length)
                    $('.candidate', $mlist).first().addClass('selected');
	    });

	// item in the mlist
	var $antimapped = 
	    $('.selected', $mlist)
	       .removeClass('selected')
	       .addClass('rejected');

	// global attribute container
	var $choice = $container
	    .find('.choice')
	    .removeClass('new-mapping')
	    .addClass('new-antimapping');

	reset_and_display_slider($container.next(), $choice);
	
	$container.find('.status').addClass('dirty');

	update_save_button();
	
	$container
	    .find('.status')
	    .text('rejected');

	$container
        .closest('tr')
	    .find('.score-color')
	    .css('background-color', '#627AAD');

    });	
});


$(reset_buttons).each( function () {
    var $container = $(this).parent().closest('tr');
    var $mlist = $container.find('.map-list');

    $(this).click( function () {
	$container.next().hide();
	$container
            .removeClass('mapped')
	    .removeClass('antimapped')
            .addClass('unmapped')

            .find('.match')
                .find('.button')
                    .removeClass('disabled')
                .end()
	        .find('.choice')                //div that displays curr. choice
	            .removeClass('new-mapping') //unmap
	            .removeClass('new-antimapping')
	            .data('confidence', 0)      //reset user's confidence rating
	        .end()
	    .end()

	    .find('.status')
                .removeClass('dirty')
	        .text('unmapped')
	    .end();

	$('.dirty', $container).removeClass('dirty');

	// wipe out confidence scores.
	$('.candidate', $mlist).each( function () {
	    $(this).data('confidence', 0);
	});

	$('.rejected', $mlist).each( function () {
	    $(this).removeClass('rejected');
	});

	$('.selected', $mlist).removeClass('selected');
	$('.candidate', $mlist).first().addClass('selected');

	update_mapping_choice($mlist);
	update_save_button();
    });
});

function load_source(sourceId){
    var $window = $('.pane.right'),
    table = $('.viewTable');

    var opts = {
	  lines: 13, // The number of lines to draw
	  length: 7, // The length of each line
	  width: 4, // The line thickness
	  radius: 10, // The radius of the inner circle
	  corners: 1, // Corner roundness (0..1)
	  rotate: 0, // The rotation offset
	  color: '#000', // #rgb or #rrggbb
	  speed: 1, // Rounds per second
	  trail: 60, // Afterglow percentage
	  shadow: false, // Whether to render a shadow
	  hwaccel: false, // Whether to use hardware acceleration
	  className: 'spinner', // The CSS class to assign to the spinner
	  zIndex: 2e9, // The z-index (defaults to 2000000000)
	  top: 'auto', // Top position relative to parent in px
	  left: 'auto' // Left position relative to parent in px
    };    

    var target = document.getElementById('top-spin');
    var status = document.getElementById('top-status');
    var cont = document.getElementById('status-container');
    var spinner = new Spinner(opts).spin(target);

    $(status).text('Loading data source...');
    $(cont).show();

    fetch_data_table(sourceId, function(data) {
	table.replaceWith(data);
	fetch_source_meta(sourceId, function(data) {
	    $('.source-meta').replaceWith(data);
	});
	toggle_panel();

	// clean up
        $(cont).hide();
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

function fetch_source_meta (sourceId, callback) {
    var rPath = /^\/doit\/\w+\//;
    var basePath = rPath.exec(location.pathname).toString();
    var url = basePath + 'sources/' + sourceId + '/meta';
    $.get(url, {}, callback);
}

function fetch_data_table (sourceId, callback) {
    var rPath = /^\/doit\/\w+\//;
    var basePath = rPath.exec(location.pathname).toString();
    var url = basePath + 'sources/' + sourceId + '/table';
    $.get(url, {}, callback);
}

$(viewsource_buttons).each(function() {
    var source_id = $(this).data('source-id');
    var source_name = $(this).data('source-name');
    $(this).click( function () {
	load_source(source_id);
	// $('.toggle-data-panel')
	//     .data('placement', 'bottom')
	//     .data('delay', {show : 500, hide : 0})
	//     .attr('title', source_name)
	//     .tooltip();
	$('.current-source').text(source_name);
    });
});

$('.toggle-data-panel').each(
    function(){
	$(this).click(function(){
	    toggle_panel();
	});
    });


/* match list dropdowns */

$(dropdown_buttons).each(function() {
    var list = $(this).closest('.per-row-actions').find('.map-list');
    $(this).click(function(e) {
	if($(this).is('.disabled')){
	    return;
	}
	load_match_list(list);
    });
});

function load_match_list(mlist) {
    // if it's empty, fetch the mappings.
    if (!$(mlist).children().length) {
        var field_id = $(mlist).closest('tr').find('.choice')
                           .attr('id').split('-is-')[0];
        fetch_match_list(mlist, field_id);
    }
}

function fetch_match_list(mlist, field_id, afterLoad) {
    afterLoad = (typeof afterLoad === 'function') ? afterLoad : function () {};
    var url = basePath + 'fields/' + field_id + '/candidates/',
        data = {},
        callback = function (responseText) {
            $(mlist).html(responseText);
	    $('.candidate', mlist).click(function () {
		$('.selected').removeClass('selected');
		$(this).addClass('selected');
		update_mapping_choice(mlist);
		$(mlist).closest('tr').find('.accept').click();
	    });
            afterLoad();
        };
    $(mlist).html('<p>Loading...</p>');
    $.get(url, data, callback);
}

function update_mapping_choice (mlist) {
    var choice = $('.selected', mlist);
    if(!$(choice).attr('id')){
	return;
    }
    var mapping = $(choice).attr('id').split('-to-');
    var fromId = mapping[0];
    var toId = mapping[1];
    var name = $(choice).text();
    var borderColor = $(choice).css('border-left-color');
    var title = $(choice).attr('title');
    var target = $(choice).closest('tr').find('.choice');

   $(target)
	.find('.match-name')
        .text(name);

   $(target)
        .attr('id', fromId + '-is-' + toId)
        .attr('data-original-title', title)
        .attr('title', title)
        .closest('tr')
        .find('.score-color')
	    .css('background-color', borderColor)
        .end()
        .end();

    update_score_tooltips();
}

$('.filter').each(function(){
    $(this).click(function(e){
	// make sure that dropdown doesn't close
	e.stopPropagation();
    });
});

/* match list filters */
$('.map-list-cont')
    .find('.filter')
    .children()
    .keyup(function (e) {
	e.stopPropagation();
        update_filter(this);
    });

function update_filter (inputEl) {
    var patterns = $(inputEl).val().toLowerCase().split(' ');
    var listElems = $(inputEl).closest('.map-list-cont').find('.candidate');
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
    var answerer_id = 0;
    var mappings = [];
    var rejected = [];

    var matchers = $('.map-list');

    // collect changes
    $('.new-mapping').each(function () {
	mappings.push(
	    $(this).attr('id').split('-is-').concat([$(this).data('confidence')])
	); 
    });


    $('.new-antimapping').each(function () {
	rejected.push(
	    $(this).attr('id').split('-is-').concat([$(this).data('confidence')])
	);
    });

    // fetch data retrieved from expertsrc
    var page_data = $('input#page-data');
    var answerer_id = $(page_data).data('answerer-id');
    var page_size = $(page_data).data('page-size');
    var expertsrc_url = $(page_data).data('expertsrc-url');
    var domain_id = $(page_data).data('domain-id');

    var any_changed = (mappings.length + rejected.length) > 0;
    
    if(!any_changed) {
	    return;
    }
    
    var msg = 
	"After you save your answers, you cannot alter them. " +
	"Are you sure?";

    var save_anyway = confirm(msg);

    if (save_anyway) {
        var url = basePath + 'save',
            data = 'mappings=' + JSON.stringify(mappings) +
                   '&rejects=' + JSON.stringify(rejected) +
	           '&answerer_id=' + answerer_id,
            callback = function (d) {

		$('.confidence').hide();

		$('.new-mapping').each(function() {
		    $(this).removeClass('new-mapping')
            .closest('.mapper-row')
		    .addClass('hide');
        });

		$('.new-antimapping').each(function() {
		    $(this).removeClass('new-antimapping')
            .closest('.mapper-row')
		    .addClass('hide');
        });

		$('.dirty').each(function() {
		    $(this).removeClass('dirty').addClass('committed');
		});

		update_save_button();

		var msg = $('.msg').first();

		if($('.mapper-row').length == $('.mapper-row.hide').length){
		    $(msg)
			.show()
		        .find('.msg-text')
			.text('Loading more questions...');
		    setTimeout(function () {
			$(msg).hide('fade');
			// TODO: push items out of the queue before doing this...
            // TODO add domain id to this crap
			window.location = expertsrc_url + '/answer/' + domain_id + '/next_question';
		    }, 1500);
		} else {
		    $(msg)
			.show()
		        .find('.msg-text')
			.text('Saved successfully.');
		    setTimeout(function () {
			$(msg).hide('fade');
		    }, 1500);
		}
            };
        $.post(url, data, callback);
    }
});

$backButton.click(function() {
    var url = $('#backlink').attr('href');
    var msg = "You have unsaved work. Do you want to abandon your changes?";
    if (page_has_unsaved_content()){
	var really_leave = confirm(msg);
	if (really_leave) {
	    window.location = url;
	}
    } else {
	window.location = url;
    }
});


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
    var fid = $(this).closest('tr').attr('id').slice(3);
    $(this).click( function () {
	fill_popover(basePath + 'fields/' + fid + '/summary', 600);
    });
});



/* Popovers */

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
//    $('.tooltip-container.score').tooltip({selector:'div[rel=tooltip]', placement:'left'});
}

function init_static_tooltips () {
    $('.tooltip-container.example').tooltip({
	selector:'span[rel=tooltip]', 
	delay: {show: 250, hide:0 },
	placement:'bottom'});
    $('.tooltip-container.source-name').tooltip({
	selector:'div[rel=tooltip]', 
	delay: {show: 250, hide:0 },
	placement:'bottom'});
    $('.actions').tooltip({
	selector:'.btn-tooltip',
	delay: {show: 250, hide:0 },
	placement:'top'
    });
}



/*confidence sliders*/

function reset_and_display_slider($container, $choice) {
    // $container = the tr containing the confidence slider
    // $choice = the item that has been mapped or rejected

    var init_value = 66;

    $btns = $container.find('.confidence-btns');
    $btns.find('input:radio[value='+init_value+']').attr('checked', 'checked');
    $choice.data('confidence', init_value);

    // show the slider container
    $container.show();
    var done_btn = $container.find('.done-with-confidence');

    $(done_btn).unbind().click(function(){
	    $choice.data('confidence', $container.find(":radio:checked").first().val());
	    $container.hide();
    });
}    

function init_conf_btns() {
    var init_value = 66;
    $("input:radio[name=conf]").each(
    function() {
        if ($(this).val() == init_value){
            $(this).attr('checked', 'checked');
        }
        $(this).click(
            function () {
                $(this).closest('.confidence-btns').data('confidence', $(this).val());
            }
        );
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


/* my lame attempt to pool all the stuff that has to be init'd on page load together */

function init_page() {
    init_help();
    update_score_tooltips();
    init_static_tooltips();
    init_conf_btns();
}

$(function() {
    init_page();
});
