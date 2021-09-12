.PHONY: all clean

S = content

T = public_html

NEEDS = $(T)/index.html \
        $(T)/instructions/index.html \
        $(T)/instructions/module1-checkin.html \
        $(T)/instructions/module2-checkin.html \
        $(T)/workshop/additional-resources-1.html \
        $(T)/workshop/community-agreement-2.html \
        $(T)/workshop/learning-objective.html \
        $(T)/workshop/module2.html \
        $(T)/workshop/additional-resources-2.html \
        $(T)/workshop/community-agreement.html \
        $(T)/workshop/mental-health-data.html \
        $(T)/workshop/scavenger-hunt.html \
        $(T)/workshop/body-classroom.html \
        $(T)/workshop/discuss-wellbeing.html \
        $(T)/workshop/mental-wellbeing.html \
        $(T)/workshop/teaching-to-transgress.html \
        $(T)/workshop/choose-adventure.html \
        $(T)/workshop/index.html \
        $(T)/workshop/module1.html \
        $(T)/workshop/titl.html


PANDOC = sed 's/\.md/\.html/g' | pandoc -s -c "http://www.columbia.edu/~akm2203/pandoc.css" --from markdown --to html5

HOME_LINK = sed -z 's/---\n\(.*\n\)*---\n/&\n[{Back to Home}](index.html)\n/'

define add_comments
$(HOME_LINK) | { cat - ;  printf "\n---------------\n\n### [Post comments]($(1))\n\nI am too technologically illiterate to set up a comment system on this page, but comments and questions are very welcome and encouraged through Github's issue system: [just click here]($(1))! (I know it's kind of a hack but it should work well enough.)\n" ; } | $(PANDOC)
endef

all : $(NEEDS)

$(T)/%.html : $(S)/%.md Makefile
	cat $< |  $(PANDOC) > $@

clean :
	rm -rf $(NEEDS)
