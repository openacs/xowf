function handleSearch () {
    var searchTerm_orig = document.getElementById("search-question-string").value;
    var searchTerm = searchTerm_orig;

    // search for quoted text and add it to the token array
    // remove the quoted string from the searchTerm
    var pattern = /".*?"/g;
    var current;
    var tokens_quoted = [];
    while(current = pattern.exec(searchTerm_orig)) {
        console.log (current[0]);
        searchTerm = searchTerm.replace(current[0],'');
        tokens_quoted.push(current[0].replace(/"/g,""));
    }

    // split the rest of the searchTerm and add it to the token array
    var tokens = searchTerm
                  .toLowerCase()
                  .split(' ')
                  .filter(function(token){
                    return token.trim() !== '';
                  });

    tokens = tokens.concat(tokens_quoted);

    var searchTermRegex = '';
    if(tokens.length) {
        searchTermRegex = new RegExp(tokens.join('|'), 'gim');
    }
    var searchContentChecked = document.getElementById("search-content").checked;

    var questions = document.getElementsByClassName('test-item');
    for (var i = 0; i < questions.length; i++) {
        question_info = questions.item(i).getAttribute('data-item_type');
        if (questions.item(i).querySelector('.grading-box') != null) {
            var text = questions.item(i).querySelector('.grading-box').dataset.title;
        } else {
            //fallback if no grading-box is rendered
            var text = questions.item(i).textContent;
        }
        if (searchContentChecked) {
            text = questions.item(i).textContent;
        }
        if (searchTermRegex == '' || text.match(searchTermRegex)) {
            questions.item(i).style.display = 'block';
        } else {
            questions.item(i).style.display = 'none';
        }
    }
    return;
}
