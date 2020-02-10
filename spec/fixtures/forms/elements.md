# This is a slide with some questions

correct -> This question has a correct answer. =
    (=) True
    () False

none -> This question has no correct answer. =
    () True
    () False

named -> This question has named answers. =
    () one -> the first answer
    (=) two -> the second answer
    () three -> the third answer

correctcheck -> This question has a correct answer. =
    [=] True
    [] False

nonecheck -> This question has no correct answer. =
    [] True
    [] False

namedcheck -> This question has named answers. =
    [] one -> the first answer
    [=] two -> the second answer
    [] three -> the third answer

name = ___

namelength = ___[50]

nametoken -> What is your name? = ___[50]

comments = [   ]

commentsrows = [   5]

smartphone = () iPhone () Android () other -> Any other phone not listed

awake -> Are you paying attention? = (x) No () Yes

smartphonecheck = [] iPhone [] Android [x] other -> Any other phone not listed

phoneos -> Which phone OS is developed by Google? = {iPhone, [Android], Other }

smartphonecombo = {iPhone, Android, (Other) }

smartphonetoken = {iPhone, Android, (other -> Any other phone not listed) }

cuisine -> What is your favorite cuisine? = { American, Italian, French }

cuisinetoken -> What is your favorite cuisine? = {
      US -> American
      IT -> Italian
      FR -> French
    }
