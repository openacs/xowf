function traverseQuestions (callback) {
    for (const question of document.querySelectorAll('.test-item')) {
        callback(question);
    }
}

function filterNotGraded () {
    const checked = document.querySelector('#search-not-graded').checked;
    traverseQuestions(function (question) {
        const grade = question.querySelector('.grading-box > .points');
        const isGraded = grade && grade.textContent !== '';
        question.style.display = checked && isGraded ? 'none' : 'block';
    });
}

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

    traverseQuestions(function (question) {
        // question_info = question.getAttribute('data-item_type');
        if (question.querySelector('.grading-box') != null) {
            var text = question.querySelector('.grading-box').dataset.title;
        } else {
            //fallback if no grading-box is rendered
            var text = question.textContent;
        }
        if (searchContentChecked) {
            text = question.textContent;
        }
        if (searchTermRegex == '' || text.match(searchTermRegex)) {
            question.style.display = 'block';
        } else {
            question.style.display = 'none';
        }
    });
}
