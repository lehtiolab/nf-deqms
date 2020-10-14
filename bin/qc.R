#!/usr/bin/env Rscript

library(ggplot2)
library(forcats)
library(reshape2)
library(ggrepel)
library(argparse)

parser <- ArgumentParser()
parser$add_argument('--feattype', type='character')
parser$add_argument('--sampletable', type='character', default=FALSE)
opt = parser$parse_args()

nrsets = length(opt$sets)
feattype = opt$feattype
sampletable = opt$sampletable
feats = read.table("feats", header=T, sep="\t", comment.char = "", quote = "")
sampletable = read.table(sampletable, header=F, sep='\t', comment.char='', quote='', colClasses=c('character'))
colnames(sampletable) = c('ch', 'set', 'sample', 'group')
rownames(sampletable) = apply(sampletable[c('group', 'sample', 'set', 'ch')], 1, paste, collapse='_')
rownames(sampletable) = gsub('[^a-zA-Z0-9_]', '_', rownames(sampletable))
rownames(sampletable) = sub('^([0-9])', 'X\\1', rownames(sampletable))
use_sampletable=TRUE

if (length(grep('plex', names(feats)))) {
  tmtcols = colnames(feats)[setdiff(grep('plex', colnames(feats)), grep('quanted', colnames(feats)))]
}

width = 4
height = 4


# DEqMS volcano plots
deqpval_cols = grep('_sca.P.Value$', names(feats))
deqFC_cols = grep('_logFC$', names(feats))
names(feats)[1] = 'feat'
if (length(deqpval_cols)) {
  s_table = unique(sampletable[sampletable$group != 'X__POOL', 'group'])
  s_table = sub('^([0-9])', 'X\\1', s_table)
  cartprod = expand.grid(s_table, s_table)
  cartprod = cartprod[cartprod$Var1 != cartprod$Var2,]
  for (comparison in paste(cartprod$Var1, cartprod$Var2, sep='.')) {
    logfcname = sprintf('%s_logFC', comparison) 
    if (length(grep(logfcname, names(feats)))) {
      compnice = sub('[.]', ' vs. ', comparison)
      logpname = sprintf('%s_log.sca.pval', comparison)
      feats[, logpname] = -log10(feats[, sprintf('%s_sca.P.Value', comparison)])
      png(sprintf('deqms_volcano_%s', comparison))
      plot = ggplot(feats, aes(x=get(sprintf('%s_logFC', comparison)), y=get(logpname), label=feat)) +
        geom_point(size=0.5 )+ theme_bw(base_size = 16) + # change theme
        theme(axis.title=element_text(size=25), axis.text=element_text(size=20)) +
        xlab(sprintf("log2 FC(%s)", compnice)) + # x-axis label
        ylab('-log10 P-value') + # y-axis label
        geom_vline(xintercept = c(-1,1), colour = "red") + # Add fold change cutoffs
        geom_hline(yintercept = 3, colour = "red") + # Add significance cutoffs
        geom_vline(xintercept = 0, colour = "black") # Add 0 lines
      if (feattype != 'peptides') {
	topfeats = feats[order(feats[logpname], decreasing=TRUE)[1:10], ]
        plot = plot + geom_text_repel(data=topfeats)
      }
      print(plot)
      dev.off()
    }
  }
}


# PCA
if (use_sampletable) {
  topca = na.omit(feats[,tmtcols])
  if (nrow(topca)) {
    pca_ana <- prcomp(t(topca), scale. = TRUE)
    score.df <- as.data.frame(pca_ana$x)
    rownames(score.df) = sub('_[a-z0-9]*plex', '', rownames(score.df))
    score.df$type = sampletable[rownames(score.df), "group"]
  
    #Scree plot
    contributions <- data.frame(contrib=round(summary(pca_ana)$importance[2,] * 100, 2)[1:20])
    contributions$pc = sub('PC', '', rownames(contributions))
    svg('scree', width=width, height=height)
    print(ggplot(data=contributions, aes(x=reorder(pc, -contrib), y=contrib)) +
      geom_bar(stat='identity') +
      theme_bw() + theme(axis.title=element_text(size=15), axis.text=element_text(size=5)) +
      ylab("Contribution (%)") + xlab('PC (ranked by contribution)'))
    dev.off()
    svg('pca', width=width, height=height)
    print(ggplot(data=score.df, aes(x=PC1, y=PC2, label=rownames(score.df), colour=type)) +
      geom_hline(yintercept = 0, colour = "gray65") +
      geom_vline(xintercept = 0, colour = "gray65") +
      geom_point(size=4) +
      theme_bw() + theme(axis.title=element_text(size=15), axis.text=element_text(size=10),
  		       legend.position="top", legend.text=element_text(size=10), legend.title=element_blank()) +
      xlab(sprintf("PC1 (%s%%)", contributions$contrib[1])) + ylab(sprintf("PC2 (%s%%)", contributions$contrib[2]))
      )
    dev.off()
  }
}
